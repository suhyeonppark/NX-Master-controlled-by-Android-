import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/command_result.dart';
import '../models/device_status.dart';
import 'feedback_parser.dart';

class NxConnection extends ChangeNotifier {
  NxConnection({
    required NxConnectionConfig Function() config,
    void Function(NxFeedback feedback)? onFeedback,
  })  : _config = config,
        _onFeedback = onFeedback;

  final NxConnectionConfig Function() _config;
  final void Function(NxFeedback feedback)? _onFeedback;
  final FeedbackParser _parser = const FeedbackParser();

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _connecting = false;
  String _buffer = '';

  DeviceStatus _status = const DeviceStatus();
  DeviceStatus get status => _status;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_connect());
  }

  void restart() {
    stop();
    start();
  }

  void stop() {
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _setStatus(const DeviceStatus());
  }

  Future<CommandResult> send(String command) async {
    if (!_started) start();
    final socket = _socket;
    if (socket == null) {
      await _connect();
    }
    final active = _socket;
    if (active == null) {
      return CommandResult.fail(
        _status.detail ?? 'NX 연결이 되어 있지 않습니다.',
        sentCommands: [command],
      );
    }
    try {
      active.add(ascii.encode(command));
      await active.flush().timeout(_config().timeout);
      return CommandResult.ok('명령 전송됨', sentCommands: [command]);
    } catch (e) {
      _dropSocket('전송 실패: $e');
      return CommandResult.fail('전송 실패: $e', sentCommands: [command]);
    }
  }

  Future<CommandResult> testConnection({
    String? hostOverride,
    int? portOverride,
  }) async {
    final c = _config();
    try {
      final socket = await Socket.connect(
        hostOverride ?? c.host,
        portOverride ?? c.port,
        timeout: c.timeout,
      );
      socket.destroy();
      return CommandResult.ok('연결 성공');
    } catch (e) {
      return CommandResult.fail('연결 실패: $e');
    }
  }

  Future<void> _connect() async {
    if (!_started || _connecting || _socket != null) return;
    _connecting = true;
    final c = _config();
    _setStatus(const DeviceStatus(state: DeviceConnectionState.checking));
    try {
      final socket = await Socket.connect(c.host, c.port, timeout: c.timeout);
      if (!_started) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _buffer = '';
      _subscription = socket.listen(
        _onData,
        onError: (Object e) => _dropSocket('수신 오류: $e'),
        onDone: () => _dropSocket('연결 종료'),
        cancelOnError: true,
      );
      _setStatus(const DeviceStatus(state: DeviceConnectionState.online));
    } catch (e) {
      _setStatus(DeviceStatus(
        state: DeviceConnectionState.offline,
        detail: '연결 실패: $e',
      ));
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onData(List<int> data) {
    _buffer += utf8.decode(data, allowMalformed: true);
    while (true) {
      final idx = _buffer.indexOf('\n');
      if (idx < 0) break;
      final line = _buffer.substring(0, idx).replaceAll('\r', '');
      _buffer = _buffer.substring(idx + 1);
      final feedback = _parser.parse(line);
      if (feedback != null) _onFeedback?.call(feedback);
    }
  }

  void _dropSocket(String detail) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    if (_started) {
      _setStatus(DeviceStatus(
        state: DeviceConnectionState.offline,
        detail: detail,
      ));
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_started || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _setStatus(DeviceStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
