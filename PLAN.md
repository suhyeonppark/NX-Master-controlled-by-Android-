# NX-2200 Controller — 구현 계획 (Codex 핸드오프)

태블릿용 Flutter 컨트롤 앱. AMX **NX-2200** 컨트롤러를 **TCP 6600** 포트로 제어한다.
Relay / IR / Serial / IO 네 가지 명령을 모두 지원하고, NX가 돌려주는 **상태(피드백)를
양방향으로 수신**해 ON/OFF를 표시한다.

이 문서 하나로 Codex가 처음부터 끝까지 구현할 수 있도록 작성했다. 기준 코드베이스는
형제 폴더 **`../Integrated Controller by Android`** (기존 CE-IRS4/CE-REL8 앱)이며,
**구조는 그대로 재사용하고 "명령 계층(device/command layer)"만 NX로 교체**한다.

---

## 0. 한눈에 보기

| 항목 | 값 |
|------|-----|
| 대상 장비 | AMX NX-2200 (NetLinx, 사용자 프로그램이 아래 문자열을 파싱) |
| 전송 | TCP, 포트 **6600** |
| 명령 종결자 | **CRLF (`\r\n`)** — 모든 명령 끝에 붙인다 |
| 인코딩 | ASCII (Serial 메시지에 한해 UTF-8 허용, §3.4 확인) |
| 연결 모델 | **영속 소켓 1개**: 명령 송신 + 상태 수신을 한 연결에서 (양방향) |
| 지원 명령 | relay, ir, serial, IO |
| 피드백 | NX → 앱 상태 통지 수신 (§4) |
| 플랫폼 | Android 태블릿(가로). 기존 앱과 동일 |

---

## 1. 명령 프로토콜 (핵심)

기본 형식:

```
set/<command_id>/<args...>\r\n
```

`set` 다음에 `/`로 구분된 토큰들이 오고, 마지막에 `\r\n`을 붙여 TCP로 보낸다.
NX가 알아서 처리한다(앱은 절대 다른 곳에서 문자열을 만들지 않는다 — 명령 계층 한 곳에서만 생성).

### 1.1 Relay

```
set/relay/<ch>/<value>\r\n
```
- `ch`: 릴레이 채널 번호 (1부터)
- `value`: `1` = ON(닫힘), `0` = OFF(열림)
- 예: 3번 릴레이 ON → `set/relay/3/1\r\n`

### 1.2 IR

```
set/ir/<ir_port>/<ch>\r\n
```
- `ir_port`: IR 출력 포트 번호
- `ch`: IR 채널/기능 코드 (NX의 IR 파일에 정의된 함수 번호)
- 예: IR 포트 2의 채널 5 → `set/ir/2/5\r\n`

### 1.3 Serial

```
set/serial/<port>/<message>\r\n
```
- `port`: 시리얼 포트 번호
- `message`: 임의 문자열. **3번째 `/` 이후 ~ `\r\n` 직전까지 전부**가 메시지다.
  - 메시지에 `/`, 공백 포함 가능. 메시지 자체에 `\r\n`이 들어갈 경우 처리는 §5 확인.
- 예: 포트 1에 `PWR ON` → `set/serial/1/PWR ON\r\n`

### 1.4 IO

```
set/io/<port>/<ch>/<value>\r\n
```
- command_id는 **소문자 `io`** (전부 소문자).
- `port`: IO 포트
- `ch`: 채널
- `value`: `1` = ON, `0` = OFF (디지털)
- 예: IO 포트 1, 채널 3, ON → `set/io/1/3/1\r\n`

### 1.5 요약 표

| 기능 | 명령 문자열(끝에 `\r\n`) | 인자 |
|------|--------------------------|------|
| Relay | `set/relay/{ch}/{value}` | ch, value(1=on/0=off) |
| IR | `set/ir/{ir_port}/{ch}` | ir_port, ch |
| Serial | `set/serial/{port}/{message}` | port, message(자유 문자열) |
| IO | `set/io/{port}/{ch}/{value}` | port, ch, value(1=on/0=off) |

---

## 2. 양방향 피드백 (상태 수신)

**NX가 상태를 돌려준다.** 응답 라인은 송신과 달리 **`set/` 접두사가 없고**
`command_id/args` 형식이다(끝맺음 `\r\n` 가정). 앱은 영속 TCP 연결에서 이 라인을 파싱해
릴레이/IO 현재 상태를 UI에 ON/OFF로 표시한다.

### 2.1 응답 형식 (확정)

| 도메인 | 응답 라인 | 비고 |
|--------|-----------|------|
| relay | `relay/<ch>/<value>` | value 1=on, 0=off |
| ir | (응답 없음) | IR은 피드백 안 옴 |
| serial | `serial/<port>/<message>` | 수신 시리얼 메시지(에코/디바이스 응답) |
| io | `io/<port>/<ch>/<value>` | value 1=on, 0=off |

- 핵심 대칭: 송신 `set/relay/3/1` → 응답 `relay/3/1`.
- relay/io 응답으로 **실제 ON/OFF 상태**를 갱신한다.
- serial 응답은 포트로 들어온 메시지이므로(상태값이 아님) 별도 처리:
  로그/최근 수신 표시 정도. ON/OFF 상태로 쓰지 않는다.

### 2.2 수신 파이프라인 (구현)
- 영속 소켓 inbound 스트림을 **`\r\n`(견고하게 `\n`도 허용) 기준으로 라인 분할**.
- 각 라인을 `FeedbackParser`로 해석:
  - 첫 토큰(`relay`/`serial`/`io`)으로 분기, 나머지를 `/`로 split.
  - serial은 `serial/<port>/` 이후 전부를 message로(나머지에 `/` 포함 가능).
- relay/io → `DeviceStateStore`(키: 도메인+포트+채널 → bool) 갱신 후 notify → UI 반영
  (`ControlButton.active`로 현재 ON 표시).
- serial → 최근 수신 메시지 스트림(선택적 UI). 
- 파싱 불가 라인은 조용히 무시(로그만).
- 연결 끊기면 백오프 후 자동 재연결 (기존 `CeRel8Subscription` 패턴 차용).

> 참고: NX가 상태를 **변화 시 자동 push**하는지, 아니면 앱이 먼저 `set`을 보냈을 때만
> 회신하는지에 따라 초기 상태 동기화 방식이 달라진다. 앱 시작 시 현재 상태를 받으려면
> 폴링/쿼리(`get/...` 등) 지원 여부는 §5에서 확인.

---

## 3. 아키텍처 — 기존 앱에서 무엇을 재사용/교체하나

기준 앱(`../Integrated Controller by Android/lib`)의 레이어를 거의 그대로 가져오되,
**device/command 레이어만 NX로 교체**한다.

### 3.1 그대로 재사용 (구조/패턴 유지)
- `app_state.dart` — 앱 전역 상태 + 서비스 와이어링 (`ChangeNotifier` + `AppScope`)
- `actions/action_router.dart` — action_id → 실제 명령 디스패치 (분기만 확장)
- `actions/action_ids.dart`, `actions/macro_registry.dart`, `actions/interlock_manager.dart`
- `config/` — `AppConfig`, `ConfigRepository`, `ButtonRepository`, `default_buttons.dart`
- `models/button_config.dart` — 편집 가능 버튼 (필드 확장)
- `widgets/` 전체 — `ControlButton`, `DeviceCard`, `SectionCard`, `grouped_buttons_view`,
  `status_bar`, `confirm_dialog` 등
- `screens/` — home / ir / power / settings + main_shell (탭 확장)
- WoL 기능(`ce/wol_client.dart`, `models/wol_pc.dart`)도 원하면 그대로 이식 (NX와 무관, 독립)

### 3.2 교체/신규 (NX 명령 계층)
- **삭제/대체**: `ce/ce_irs4_client.dart`, `ce/ce_rel8_client.dart`,
  `ce/ce_rel8_subscription.dart` (CE 전용)
- **신규 transport**: `nx/nx_connection.dart`
  - 영속 TCP 소켓 1개 유지(6600). 송신 큐 + 수신 라인 스트림.
  - 자동 재연결, 연결상태(online/offline/checking) 통지.
  - 모든 메서드는 절대 throw하지 않고 `CommandResult` 반환(기존 규약 유지).
- **신규 명령 빌더**: `nx/nx_command.dart`
  - `relay(ch, value)`, `ir(port, ch)`, `serial(port, msg)`, `io(port, ch, value)` →
    각각 `set/...\r\n` 문자열 생성. **여기 한 곳에서만 와이어 포맷 생성**.
- **신규 피드백 파서**: `nx/feedback_parser.dart` (§2.2). 교체 쉽게 독립.
- **상태 저장소**: `nx/device_state_store.dart` — 채널별 최신값 맵 + notify.

### 3.3 데이터 흐름
```
UI(ControlButton) → AppState.runAction(id)
      → ActionRouter.run(def)
            → NxCommand 빌드 → NxConnection.send("set/...\r\n")
NX → NxConnection 수신 스트림 → FeedbackParser → DeviceStateStore → notify → UI 갱신
```

---

## 4. 데이터 모델 변경

### 4.1 ActionDef (sealed) — `actions/action_models.dart`
기존: `IrAction`, `RelayAction`, `MacroAction`, (`WolAction`).
추가/조정:
- `RelayAction { int ch; int value; /* 또는 RelayMode */ }` — NX는 `set/relay/ch/value`.
  - 단순화: `value`(0/1) 직접. 모멘터리(펄스)가 필요하면 `momentary + durationMs`로
    1 전송 → 지연 → 0 전송 (라우터에서 처리). §5에서 모멘터리 지원 방식 확인.
- `IrAction { int irPort; int ch; }` — NX는 `set/ir/port/ch` (숫자 채널). 기존의 named/numbered
  구분 제거.
- **신규** `SerialAction { int port; String message; }`
- **신규** `IoAction { int port; int ch; int value; }`
- `MacroAction` 그대로 (여러 action 순차 실행).

라우터 `switch (def)`에 `SerialAction`, `IoAction` 분기 추가.

### 4.2 ButtonConfig — `models/button_config.dart`
- `enum ButtonType { relay, ir, serial, io }`
- `enum ButtonScreen { relay, ir, serial, io }` (탭과 매핑) — 또는 기존처럼 그룹으로 묶기
- 각 타입별 파라미터 필드 추가: relay(ch,value), ir(irPort,ch),
  serial(port,message), io(port,ch,value)
- `toActionDef()`에 4종 분기
- `toJson/fromJson` 확장 + **레거시 마이그레이션 불필요**(새 앱, 새 저장키 사용 권장:
  `app_config_v1`/버튼 저장키를 새 이름으로)

### 4.3 AppConfig — `config/app_config.dart`
- CE-IRS4/REL8 두 장비 IP/포트 → **NX 단일 장비**로 단순화:
  - `nxIp`(기본값 예: `192.168.1.100`), `nxPort`(기본 **6600**)
  - `tcpTimeoutMs`, `buttonLockMs`는 유지
  - (WoL 이식 시 `pcs` 유지)
- `toJson/fromJson/copyWith` 갱신

---

## 5. 확인 필요 항목 (NX 프로그램/문서 대조)

> Codex는 아래를 **가정값으로 구현하되 한 곳(상수/주석)에 모아** 두고, 실제 값 확인 시
> 쉽게 바꿀 수 있게 한다.

**확정된 사항** (더 확인 불필요):
- 명령 접두사 `set/`, 응답은 접두사 없음(`command_id/args`).
- command_id 전부 소문자: `relay` / `ir` / `serial` / `io`.
- relay·io value: `1=ON / 0=OFF` (디지털).
- IR은 응답 없음.

**남은 확인 항목**:
1. **모멘터리(펄스)**: relay/io에 펄스 동작이 필요한가? 필요하면 앱이 `1`→지연→`0`으로
   처리(별도 command 없음 가정).
2. **채널 인덱스 base**: 1-base vs 0-base. 각 도메인별 채널/포트 개수(relay N개, IR 포트 수,
   IO 포트·채널 수, serial 포트 수) → UI 버튼 범위 결정.
3. **종결자 재확인**: 앱→NX `\r\n` 확정. NX→앱 응답의 종결자도 `\r\n`인지(파서는 `\n`도 허용).
4. **상태 동기화**: NX가 상태 변화 시 **자동 push**하는지, 아니면 `set` 회신으로만 오는지.
   앱 시작 시 현재 상태를 받으려면 쿼리(`get/...` 등) 지원 여부.
5. **Serial 메시지**: 인코딩(ASCII/UTF-8), 메시지 내 특수문자/`\r\n` 이스케이프 필요 여부.
   응답 `serial/port/msg`의 msg에 `/` 포함 가능 → 파서는 split 제한 처리.
6. **인증/세션**: 6600 접속 시 핸드셰이크/로그인 필요 여부(NX는 보통 없음, 확인).

---

## 6. UI / 탭 구성

`main_shell.dart` 하단 탭을 기능에 맞게 구성(가로 태블릿):

- **홈**: 자주 쓰는 매크로 / 전체 ON·OFF (+ 원하면 PC 켜기(WoL))
- **Relay**: 릴레이 채널별 ON/OFF (피드백으로 현재상태 표시 — `ControlButton.active`)
- **IR**: IR 포트별 채널 버튼
- **Serial**: 포트별 사전 정의 메시지 버튼 (편집 가능)
- **IO**: IO 포트/채널 값 설정 버튼 (디지털이면 토글)
- **설정**: NX IP/포트, 연결 테스트, 버튼 편집, (WoL PC 목록)

버튼은 기존처럼 **설정 → 버튼 편집**에서 사용자가 추가/삭제/수정(그룹·채널·값) 가능하게
`ButtonConfig` + `ButtonRepository` 재사용. 위험 동작은 기존 확인 다이얼로그(`confirm`) 사용.

상태바(`status_bar.dart`)의 연결 표시등은 NX 단일 연결 상태를 표시.

---

## 7. 설정 화면 (`settings_screen.dart`)

- NX IP / Port(6600) 입력 + 유효성 검사(IPv4, 1~65535)
- **연결 테스트** 버튼: 6600 소켓 connect 성공/실패 표시(기존 `_testRow` 재사용)
- TCP Timeout(ms), Button Lock(ms)
- 버튼 편집 진입
- (이식 시) WoL PC 목록 관리
- 저장 시 `AppState.saveConfig` → 영속 소켓 재연결

---

## 8. 단계별 구현 체크리스트 (Codex용)

### Phase 0 — 부트스트랩
- [ ] `../nx2200_controller`에 Flutter 프로젝트 생성
      (`flutter create --org com.example --platforms android nx2200_controller`
      또는 이 폴더에 직접). `pubspec`에 `shared_preferences`, `wakelock_plus` 추가.
- [ ] 기준 앱의 `lib/widgets`, `lib/config`, `lib/models`, `lib/actions`,
      `lib/screens`, `app_state.dart`, `app.dart`, `main.dart` 구조를 복사해 출발점으로.
- [ ] Android: 가로 고정, INTERNET 권한, 런처 아이콘(기존 `tool/gen_icon.py` 재사용 가능).

### Phase 1 — NX 명령 계층
- [ ] `nx/nx_command.dart`: 4종 명령 문자열 빌더(+`\r\n`). 단위 테스트로 와이어 포맷 고정.
- [ ] `nx/nx_connection.dart`: 영속 소켓(6600), 송신, 수신 라인 스트림, 자동 재연결,
      연결상태 통지. 모든 경로에서 throw 금지 → `CommandResult`.
- [ ] `models/command_result.dart`, `models/device_status.dart` 기준 앱에서 이식.

### Phase 2 — 액션/라우팅
- [ ] `action_models.dart`에 `SerialAction`, `IoAction` 추가, `RelayAction`/`IrAction` NX화.
- [ ] `action_router.dart` switch 분기 4종 + 매크로.
- [ ] `action_ids.dart` 정리.

### Phase 3 — 피드백
- [ ] `nx/feedback_parser.dart`: 수신 라인 → 상태. (가정 형식, §5 확인 후 교체 용이)
- [ ] `nx/device_state_store.dart`: 채널별 상태 맵 + notify.
- [ ] `AppState`에서 수신 스트림 구독 → store 갱신 → UI(`ControlButton.active`)에 반영.

### Phase 4 — 모델/설정
- [ ] `ButtonConfig` 4타입 확장 + JSON + `default_buttons.dart`(NX 샘플 버튼).
- [ ] `AppConfig` 단일 NX 장비로 단순화 + 저장소.
- [ ] `settings_screen.dart` NX IP/포트/테스트/버튼편집.

### Phase 5 — UI/탭
- [ ] `main_shell.dart` 탭: 홈/Relay/IR/Serial/IO/설정.
- [ ] 각 화면: 버튼 그리드(`grouped_buttons_view`/`SectionCard`/`ButtonGrid` 재사용).
- [ ] Relay/IO 토글은 피드백 상태로 ON/OFF 강조.

### Phase 6 — 마감
- [ ] `flutter analyze` 무경고, 단위 테스트(명령 포맷·파서) 통과.
- [ ] 실제 NX-2200으로 4종 명령 + 피드백 검증(§5 항목 확정).
- [ ] 태블릿 release 빌드/설치.

---

## 9. 테스트 (최소)

- **명령 포맷**: 각 빌더가 정확한 문자열(+`\r\n`)을 만드는지.
  - `set/relay/3/1\r\n`, `set/ir/2/5\r\n`, `set/serial/1/PWR ON\r\n`, `set/IO/1/3/1\r\n`
- **피드백 파서**: 가정 형식 라인 → 올바른 (도메인/채널/값) 매핑, 잡음 라인 무시.
- **라우터**: action_id → 기대 명령 호출(모의 connection으로 캡처).
- **연결 회복**: 소켓 끊김 후 재연결 동작(통합/수동).

---

## 10. 핵심 규칙 (기존 앱에서 계승)

- 와이어 문자열은 **명령 빌더(nx_command.dart) 한 곳**에서만 생성. UI/라우터는 문자열 모름.
- 클라이언트/연결 계층은 **절대 throw 안 함** → 항상 `CommandResult`(성공/경고/실패, 한국어 메시지).
- "명령 전송됨" ≠ "장비 상태 바뀜". 단, 이제 **피드백으로 실제 상태를 받으므로** ON/OFF
  표시는 피드백 기준(전송 성공만으로 단정하지 않음).
- 위험 동작은 확인 다이얼로그, 버튼은 전송 후 `buttonLockMs` 잠금(중복탭 방지).

---

## 11. 참고 — 기준 코드 위치

형제 폴더: `../Integrated Controller by Android/`
- 명령 계층 예전 구현(교체 대상): `lib/ce/*`
- 영속 연결+재연결 패턴 참고: `lib/ce/ce_rel8_subscription.dart`
- 액션/라우터 패턴: `lib/actions/*`
- 편집 가능 버튼/설정: `lib/models/button_config.dart`, `lib/config/*`,
  `lib/screens/settings_screen.dart`, `lib/screens/button_*`
- 위젯/레이아웃: `lib/widgets/*`
- 런처 아이콘 생성기: `tool/gen_icon.py`
