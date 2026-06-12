import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

typedef RelayStateCallback = void Function(int relay, bool closed);
typedef Rel8SubscriptionStatusCallback =
    void Function(bool connected, String? detail);

/// Maintains a long-lived CE-REL8 subscription socket for live relay state.
///
/// Relay commands still use short-lived command sockets. This listener exists
/// only for `subscribe /relay/#/state` updates from the device.
class CeRel8Subscription {
  CeRel8Subscription({
    required this.connection,
    required this.onState,
    required this.onStatus,
  });

  final CeConnection Function() connection;
  final RelayStateCallback onState;
  final Rel8SubscriptionStatusCallback onStatus;

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;
  bool _stopped = true;
  String _pending = '';

  static const int _relayCount = 8;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  void start() {
    _stopped = false;
    unawaited(_connect());
  }

  void restart() {
    stop();
    start();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pending = '';
    unawaited(_subscription?.cancel());
    _subscription = null;
    _socket?.destroy();
    _socket = null;
  }

  Future<void> _connect() async {
    if (_stopped) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _pending = '';

    final c = connection();
    onStatus(false, 'REL8 상태 구독 연결 중...');

    try {
      final socket = await Socket.connect(c.host, c.port, timeout: c.timeout);
      if (_stopped) {
        socket.destroy();
        return;
      }

      _socket = socket;
      for (var relay = 1; relay <= _relayCount; relay++) {
        socket.add(ascii.encode('subscribe /relay/$relay/state\n'));
      }
      await socket.flush().timeout(c.timeout);
      onStatus(true, null);

      _subscription = socket.listen(
        _handleBytes,
        onDone: () => _scheduleReconnect('REL8 상태 구독 연결 종료'),
        onError: (Object e) => _scheduleReconnect('REL8 상태 구독 오류: $e'),
        cancelOnError: true,
      );
    } on SocketException catch (e) {
      _scheduleReconnect(_socketMessage(e));
    } on TimeoutException {
      _scheduleReconnect('REL8 상태 구독 시간 초과');
    } catch (e) {
      _scheduleReconnect('REL8 상태 구독 실패: $e');
    }
  }

  void _handleBytes(List<int> bytes) {
    _pending += ascii.decode(bytes, allowInvalid: true);
    while (true) {
      final lineEnd = _pending.indexOf('\n');
      if (lineEnd < 0) return;
      final line = _pending.substring(0, lineEnd).trim();
      _pending = _pending.substring(lineEnd + 1);
      if (line.isNotEmpty) _handleLine(line);
    }
  }

  void _handleLine(String line) {
    final match = RegExp(
      r'^update\s+/relay/([1-8])/state\s+(true|false)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return;

    final relay = int.parse(match.group(1)!);
    final closed = match.group(2)!.toLowerCase() == 'true';
    onState(relay, closed);
  }

  void _scheduleReconnect(String detail) {
    if (_stopped) return;
    onStatus(false, detail);
    _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () => unawaited(_connect()));
  }

  String _socketMessage(SocketException e) {
    final os = e.osError;
    if (os == null) return e.message.isEmpty ? 'REL8 상태 구독 소켓 오류' : e.message;
    final msg = os.message.toLowerCase();
    if (msg.contains('refused')) return 'REL8 상태 구독 거부됨';
    if (msg.contains('unreachable')) return 'REL8 네트워크 접근 불가';
    if (msg.contains('timed out') || msg.contains('timeout')) {
      return 'REL8 상태 구독 시간 초과';
    }
    return os.message;
  }
}
