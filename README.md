# NX-Master-controlled-by-Android

Android 컨트롤 앱(`nx2200_controller`)과 연동되는 AMX **NX-2200** NetLinx 마스터 프로그램.
앱이 TCP **6600** 포트로 접속해 명령을 보내면 통합 컨트롤러 포트(릴레이/IR/시리얼/IO)를
제어하고, 상태를 다시 앱으로 돌려준다.

## 프로토콜

모든 라인은 `\r\n`으로 끝난다. 수신 바이트는 버퍼에 누적된 뒤 줄(`\r\n`) 단위로
순서대로 처리된다.

### 앱 → NX (명령)

| 명령 | 형식 |
|------|------|
| Relay | `set/relay/<ch>/<value>` (value 1=on, 0=off) |
| IR | `set/ir/<ir_port>/<ch>` |
| Serial | `set/serial/<port>/<message>` (message는 자유 문자열) |
| IO | `set/io/<port>/<ch>/<value>` (value 1=on, 0=off) |

### NX → 앱 (피드백, `set/` 접두사 없음)

| 도메인 | 형식 |
|--------|------|
| Relay | `relay/<ch>/<value>` |
| IO | `io/<port>/<ch>/<value>` |
| Serial | `serial/<port>/<message>` |
| IR | (피드백 없음) |

릴레이/IO는 실제 채널 상태 변화를 `CHANNEL_EVENT`로 잡아 보내며, 앱이 접속하면
현재 상태를 한 번에 동기화한다.

## 포트 매핑

`by_Android.axs` 상단의 `DEFINE_DEVICE`와 `dvSerialPorts[]`/`dvIRPorts[]`/`dvIOPorts[]`
배열에서 실제 배선에 맞게 수정한다. 기본값(NX 표준):

- 릴레이: `5001:21`
- I/O: `5001:22`
- 시리얼(COM): `5001:1~`
- IR/Serial: `5001:11~` (IR 모드로 강제 설정)

## 빌드 / 디버그

NetLinx Studio 4에서 `by_Android.apw` 워크스페이스를 열어 컴파일/전송한다.

`DEBUG_LOG = 1`이면 송수신 라인이 마스터 진단 콘솔(`send_string 0`)에 출력된다.
운영 배포 시 `0`으로 변경.
