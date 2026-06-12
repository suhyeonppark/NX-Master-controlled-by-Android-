import 'dart:async';
import 'dart:io';

import '../models/command_result.dart';

/// Low-level TCP transport shared by both device clients.
///
/// Uses the simple "connect → send → close" model (spec §5 option A): one
/// short-lived socket per command. This avoids all the persistent-socket
/// pitfalls (Wi-Fi sleep, device reboot, half-open sockets) at the cost of a
/// little latency, which is fine for a control panel.
///
/// Every public method returns a [CommandResult] and NEVER throws — all socket
/// errors are caught and converted into a friendly Korean message so the UI
/// can stay alive (spec §14).
class CeTcpClient {
  /// Sends a single ASCII command and returns once it has been flushed.
  ///
  /// A trailing newline is appended automatically if missing (spec §5/§17.1).
  /// We do not wait for a meaningful reply — CE devices may or may not echo —
  /// but we do briefly drain any immediate response so the socket closes
  /// cleanly.
  Future<CommandResult> sendCommand({
    required String host,
    required int port,
    required String command,
    required Duration timeout,
  }) async {
    final payload = command.endsWith('\n') ? command : '$command\n';
    final wire = payload.trimRight(); // for diagnostics, no trailing newline

    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add(payload.codeUnits);
      await socket.flush().timeout(timeout);

      // Best-effort short read so we don't slam the socket shut mid-reply.
      // Failure/timeout here is not an error: the command was already sent.
      try {
        await socket.timeout(const Duration(milliseconds: 150)).first;
      } catch (_) {
        // No reply within the grace window — perfectly normal.
      }

      return CommandResult.ok('명령 전송됨', sentCommands: [wire]);
    } on SocketException catch (e) {
      return CommandResult.fail(_socketMessage(e), sentCommands: const []);
    } on TimeoutException {
      return CommandResult.fail('연결 시간 초과 ($host:$port)');
    } on ArgumentError {
      return CommandResult.fail('잘못된 IP 또는 포트입니다 ($host:$port)');
    } catch (e) {
      return CommandResult.fail('명령 전송 실패: $e');
    } finally {
      try {
        socket?.destroy();
      } catch (_) {
        // Ignore close errors.
      }
    }
  }

  /// Opens and immediately closes a socket to verify the device is reachable.
  /// Returns an ok/fail result with a reason on failure (used by the settings
  /// connection test).
  Future<CommandResult> testConnection({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return CommandResult.ok('연결 성공');
    } on SocketException catch (e) {
      return CommandResult.fail(_socketMessage(e));
    } on TimeoutException {
      return CommandResult.fail('connection timeout');
    } on ArgumentError {
      return CommandResult.fail('invalid IP/port');
    } catch (e) {
      return CommandResult.fail('$e');
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  String _socketMessage(SocketException e) {
    final os = e.osError;
    if (os != null) {
      // Common, user-meaningful cases.
      final msg = os.message.toLowerCase();
      if (msg.contains('refused')) return 'connection refused';
      if (msg.contains('unreachable')) return 'network unreachable';
      if (msg.contains('timed out') || msg.contains('timeout')) {
        return 'connection timeout';
      }
      return os.message;
    }
    return e.message.isEmpty ? 'socket error' : e.message;
  }
}
