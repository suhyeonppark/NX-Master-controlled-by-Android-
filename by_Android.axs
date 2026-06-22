PROGRAM_NAME='by_Android'
(***********************************************************)
(*    <->  Android 컨트롤 앱 (nx2200_controller)     *)
(*                                                         *)
(*  TCP 6600 서버. 앱이 보내는 명령을 파싱해 통합 컨트롤러     *)
(*  포트(릴레이/IR/시리얼/IO)를 제어하고, 상태를 다시 보낸다.  *)
(*                                                         *)
(*  수신(앱 -> NX)  :  set/<cmd>/<args...>\r\n               *)
(*      set/relay/<ch>/<value>          value 1=on 0=off    *)
(*      set/ir/<ir_port>/<ch>                               *)
(*      set/serial/<port>/<message>     message 는 자유문자열 *)
(*      set/io/<port>/<ch>/<value>      value 1=on 0=off    *)
(*                                                         *)
(*  송신(NX -> 앱)  :  <cmd>/<args...>\r\n  ('set/' 없음)    *)
(*      relay/<ch>/<value>                                  *)
(*      io/<port>/<ch>/<value>                              *)
(*      serial/<port>/<message>                             *)
(*      (ir 은 피드백 없음)                                  *)
(***********************************************************)

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

TCP1    = 0:3:0        // TCP 서버용 로컬 IP 소켓 (논리 포트 3)
TCP2    = 0:4:0        // TCP 서버용 로컬 IP 소켓 (논리 포트 4)
TCP3    = 0:5:0        // TCP 서버용 로컬 IP 소켓 (논리 포트 5)
TCP4    = 0:6:0        // TCP 서버용 로컬 IP 소켓 (논리 포트 6)
TCP5    = 0:7:0        // TCP 서버용 로컬 IP 소켓 (논리 포트 7)

// --- 통합 컨트롤러(5001) 물리 포트. 실제 배선에 맞춰 수정 ---
dvRELAY  = 6001:1:0    // 릴레이 포트 (채널 1..N)
dvIO_1   = 5001:22:0    // I/O 포트 (채널 1..N)

dvSER_1  = 5001:1:0     // 시리얼(COM) 포트 1
dvSER_2  = 5001:2:0
dvSER_3  = 5001:3:0
dvSER_4  = 5001:4:0

dvIR_1   = 5001:11:0    // IR/시리얼 포트 1 (IR 모드)
dvIR_2   = 5001:12:0
dvIR_3   = 5001:13:0
dvIR_4   = 5001:14:0

dvEXB_REL = 50001:1:0  //EXB-REL8
dvEXB_IRS = 50002:1:0 //EXB-IRS4

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT
DEV TCPS[] = {TCP1,TCP2,TCP3,TCP4,TCP5}

integer TCP_PORT      = 6600     // 앱이 접속하는 서버 포트
integer DEBUG_LOG     = 1        // 1=마스터 콘솔에 송수신 로그 출력

integer NUM_RELAY     = 8        // 릴레이 채널 수 (피드백 초기화에 사용)
integer NUM_IO_CH     = 8        // I/O 채널 수 (피드백 초기화에 사용)

char    CRLF[2]       = {$0D, $0A}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

// 앱의 논리 포트번호 -> 물리 디바이스 매핑. (1-base: 앱 port 1 = [1])
dev dvSerialPorts[] = { dvSER_1, dvSER_2, dvSER_3, dvSER_4 }
dev dvIRPorts[]     = { dvIR_1,  dvIR_2,  dvIR_3,  dvIR_4  }
dev dvIOPorts[]     = { dvIO_1 }

// 수신 누적 버퍼. CREATE_BUFFER 로 들어오는 바이트가 계속 쌓인다.
volatile char cRxBuffer[5][4000]

volatile integer bClientOnline[5]    // 앱 소켓 연결 여부

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function dbg(char msg[]) {
	if (DEBUG_LOG) {
		send_string 0, "'[by_Android] ', msg"
	}
}

// IR/Serial 겸용 포트를 IR 모드로 명시 설정.
// (이 포트들은 시리얼로도 쓸 수 있어 기본값을 신뢰하지 않고 강제한다.)
define_function init_ir_ports() {
	integer i
	for (i = 1; i <= length_array(dvIRPorts); i++) {
		send_command dvIRPorts[i], "'SET MODE IR'"
	}
}

// 서버 오픈. IP_SERVER_OPEN 은 한 번 열면 클라이언트가 끊겨도 계속
// 리스닝을 유지하므로 끊길 때마다 닫고 다시 열 필요가 없다.
define_function open_server(integer index) {
	ip_server_open(TCPS[index].PORT, TCP_PORT, IP_TCP)
	dbg("'server listening on tcp ', itoa(TCP_PORT)")
}

// 앱으로 한 줄 피드백 전송 (자동으로 CRLF 부착)
define_function send_feedback(char line[]) {
	send_string TCPS, "line, CRLF"
	dbg("'TX << ', line")
}

// dev 배열에서 d 의 1-base 인덱스 반환 (없으면 0)
define_function integer dev_index(dev list[], dev d) {
	integer i
	for (i = 1; i <= length_array(list); i++) {
		if (list[i] == d) {
			return i
		}
	}
	return 0
}

(*-------------------- 명령 실행 --------------------*)

// args = "<ch>/<value>"
define_function do_relay(char args[]) {
	char work[64]
	integer ch, val
	work = args
	ch  = atoi(remove_string(work, '/', 1))   // "3/" -> 3, work="1"
	val = atoi(work)
	if (ch < 1) { return }
	if (val) {
		on[dvRELAY, ch]
		} else {
		off[dvRELAY, ch]
	}
	// 실제 채널 상태 변화는 CHANNEL_EVENT[dvRELAY] 에서 피드백된다.
}

// args = "<ir_port>/<ch>"
define_function do_ir(char args[]) {
	char work[64]
	integer port, ch
	work = args
	port = atoi(remove_string(work, '/', 1))
	ch   = atoi(work)
	if (port < 1 || port > length_array(dvIRPorts) || ch < 1) { return }
	pulse[dvIRPorts[port], ch]   // IR 함수코드 = 채널번호로 1회 발사
}

// args = "<port>/<message>"  (message 안에 '/' 공백 포함 가능)
define_function do_serial(char args[]) {
	char work[1024]
	integer port
	work = args
	port = atoi(remove_string(work, '/', 1))   // "1/" 제거, work=메시지 전체
	if (port < 1 || port > length_array(dvSerialPorts)) { return }
	send_string dvSerialPorts[port], "work"
}

// args = "<port>/<ch>/<value>"
define_function do_io(char args[]) {
	char work[64]
	integer port, ch, val
	work = args
	port = atoi(remove_string(work, '/', 1))
	ch   = atoi(remove_string(work, '/', 1))
	val  = atoi(work)
	if (port < 1 || port > length_array(dvIOPorts) || ch < 1) { return }
	if (val) {
		on[dvIOPorts[port], ch]
		} else {
		off[dvIOPorts[port], ch]
	}
	// 상태 변화는 CHANNEL_EVENT[dvIOPorts] 에서 피드백된다.
}

(*-------------------- 한 줄 파싱 --------------------*)

// line: CRLF 가 제거된 한 줄. 예) "set/relay/3/1"
define_function process_line(char line[]) {
	char work[1024]
	char cmd[16]
	
	if (left_string(line, 4) != 'set/') {
		return                       // 'set/' 로 시작하지 않으면 무시
	}
	dbg("'RX >> ', line")
	
	work = line
	remove_string(work, 'set/', 1)              // 'set/' 접두사 제거
	cmd = remove_string(work, '/', 1)           // "relay/" (구분자 포함)
	if (length_string(cmd) < 2) {
		dbg("'malformed line (no command)'")
		return                                  // '/' 없음 -> 잘못된 줄
	}
	set_length_string(cmd, length_string(cmd) - 1)  // 끝의 '/' 제거
	
	select {
		active (cmd == 'relay'):  { do_relay(work) }
		active (cmd == 'ir'):     { do_ir(work) }
		active (cmd == 'serial'): { do_serial(work) }
		active (cmd == 'io'):     { do_io(work) }
		active (1):               { dbg("'unknown cmd: ', cmd") }
	}
}

// 누적 버퍼에서 완성된(LF로 끝나는) 줄을 순서대로 모두 처리.
// CRLF 가 기본이지만 끝의 CR/LF 를 벗겨내 LF 단독도 견딘다.
define_function process_rx_buffer(integer idx) {
	char line[1024]
	
	while (find_string(cRxBuffer[idx], "$0A", 1)) {
		line = remove_string(cRxBuffer[idx], "$0A", 1)   // LF 까지(포함) 잘라낸다
		// 끝의 LF / CR 제거
		while (length_string(line) &&
			((line[length_string(line)] == $0A) ||
				(line[length_string(line)] == $0D))) {
			set_length_string(line, length_string(line) - 1)
		}
		if (length_string(line)) {
			process_line(line)
		}
	}
	
	// 비정상적으로 줄바꿈 없이 버퍼만 차오르는 경우 폭주 방지
	if (length_string(cRxBuffer[idx]) > 2000) {
		dbg("'rx buffer overflow, clearing'")
		clear_buffer cRxBuffer[idx]
	}
}

// 앱 접속 시 현재 릴레이/IO 상태를 모두 내려보내 동기화
define_function sync_states() {
	integer p, ch
	for (ch = 1; ch <= NUM_RELAY; ch++) {
		send_feedback("'relay/', itoa(ch), '/', itoa(type_cast([dvRELAY, ch]))")
	}
	for (p = 1; p <= length_array(dvIOPorts); p++) {
		for (ch = 1; ch <= NUM_IO_CH; ch++) {
			send_feedback("'io/', itoa(p), '/', itoa(ch), '/', itoa(type_cast([dvIOPorts[p], ch]))")
		}
	}
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START{
	integer i
	for(i = 1; i <= 5; i++) {
		create_buffer TCPS[i], cRxBuffer[i]      // 수신 바이트를 cRxBuffer 에 자동 누적
		clear_buffer cRxBuffer[i]
		open_server(i)
	}
	wait 50 {
		init_ir_ports()                 // IR 포트 모드 설정 (포트 online 후)
	}
}
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

(*-------------------- TCP 서버 소켓 --------------------*)
data_event[TCPS] {
	online: {
		integer index
		index = get_last(TCPS)
		bClientOnline[index] = true
		dbg("itoa(index),'client connected'")
		clear_buffer cRxBuffer[index]
		sync_states()                // 현재 상태 동기화
	}
	string: {
		// create_buffer 가 이미 cRxBuffer 에 쌓아 두었다. 줄 단위로 처리.
		integer index
		index = get_last(TCPS)
		process_rx_buffer(index)
	}
	offline: {
		integer index
		index = get_last(TCPS)
		bClientOnline[index] = false
		// dbg("itoa(index),'client disconnected, reopening server'")
		// IP_SERVER_OPEN 은 클라이언트가 끊기면 리스닝 소켓도 닫힌다.
		// 다음 접속을 받으려면 반드시 다시 열어 재무장해야 한다.
		switch (index) {
			case 1: { wait 100 open_server(1) }
			case 2: { wait 100 open_server(2) }
			case 3: { wait 100 open_server(3) }
			case 4: { wait 100 open_server(4) }
			case 5: { wait 100 open_server(5) }
		}
	}
	onerror: {
		integer index
		index = get_last(TCPS)
		bClientOnline[index] = false
		// dbg("itoa(index),'socket error: ', itoa(data.number), ' - reopening server'")
		// 에러로 닫힌 경우에도 재무장한다.
		switch (index) {
			case 1: { wait 100 open_server(1) }
			case 2: { wait 100 open_server(2) }
			case 3: { wait 100 open_server(3) }
			case 4: { wait 100 open_server(4) }
			case 5: { wait 100 open_server(5) }
		}
	}
}

(*-------------------- 릴레이 상태 피드백 --------------------*)
// 채널 0 = 와일드카드: dvRELAY 의 모든 채널 변화를 잡는다.
channel_event[dvRELAY, 0] {
	on: {
		send_feedback("'relay/', itoa(channel.channel), '/1'")
	}
	off: {
		send_feedback("'relay/', itoa(channel.channel), '/0'")
	}
}

(*-------------------- I/O 상태 피드백 --------------------*)
channel_event[dvIOPorts, 0] {
	on: {
		integer p
		p = dev_index(dvIOPorts, channel.device)
		if (p) {
			send_feedback("'io/', itoa(p), '/', itoa(channel.channel), '/1'")
		}
	}
	off: {
		integer p
		p = dev_index(dvIOPorts, channel.device)
		if (p) {
			send_feedback("'io/', itoa(p), '/', itoa(channel.channel), '/0'")
		}
	}
}

(*-------------------- 시리얼 수신 -> 앱 전달 --------------------*)	
data_event[dvSerialPorts] {
	string: {
		integer p
		p = dev_index(dvSerialPorts, data.device)
		if (p) {
			send_feedback("'serial/', itoa(p), '/', data.text")
		}
	}
}

(***********************************************************)
(*                   END OF PROGRAM                        *)
(***********************************************************)
DEFINE_PROGRAM















































