import '../config/app_config.dart';
import '../models/command_result.dart';
import 'ce_tcp_client.dart';

/// Builds and sends CE-IRS4 IR control commands (spec §6, §17.2).
///
/// This is the ONLY place CE-IRS4 wire strings are constructed. UI/router code
/// must go through these methods, never craft `exec /ir/...` strings directly.
class CeIrs4Client {
  CeIrs4Client(this._tcp, this._connection);

  final CeTcpClient _tcp;

  /// Resolves the current CE-IRS4 connection params from live config.
  final CeConnection Function() _connection;

  /// `exec /ir/{port}/loadIrFile "{filename}"`
  Future<CommandResult> loadIrFile(int irPort, String filename) {
    return _send('exec /ir/$irPort/loadIrFile "$filename"');
  }

  /// `exec /ir/{port}/bufferedSendNamedIr "{irName}"` — preferred (spec §6.2).
  Future<CommandResult> sendNamedIr(int irPort, String irName) {
    return _send('exec /ir/$irPort/bufferedSendNamedIr "$irName"');
  }

  /// `exec /ir/{port}/bufferedSendIr {irNumber}` (spec §6.3).
  Future<CommandResult> sendNumberedIr(int irPort, int irNumber) {
    return _send('exec /ir/$irPort/bufferedSendIr $irNumber');
  }

  Future<CommandResult> _send(String command) {
    final c = _connection();
    return _tcp.sendCommand(
      host: c.host,
      port: c.port,
      command: command,
      timeout: c.timeout,
    );
  }
}
