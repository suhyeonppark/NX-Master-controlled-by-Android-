import '../config/app_config.dart';
import '../models/command_result.dart';
import 'ce_tcp_client.dart';

/// Builds and sends CE-REL8 relay control commands (spec §7, §17.3).
///
/// This is the ONLY place CE-REL8 wire strings are constructed.
///
/// Verified against the AMX CE-Series Instruction Manual (3rd-Party Control
/// Protocol → CE-REL8 Controls): the relay has a single read/write boolean
/// parameter `/relay/#/state` (# is the 1-based relay number). Unlike IR
/// commands (which use `exec`), relay state is set with the `set` message:
///
///   ON  / close (engaged):  `set /relay/1/state true`
///   OFF / open:             `set /relay/1/state false`
///
/// The protocol has no native momentary/pulse for relays, so [relayMomentary]
/// implements it in software (set true → wait → set false).
class CeRel8Client {
  CeRel8Client(this._tcp, this._connection, {this.onState});

  final CeTcpClient _tcp;
  final CeConnection Function() _connection;

  /// Called after a relay command succeeds, with the new latched state
  /// (`true` = closed/ON, `false` = open/OFF). Lets [AppState] track and show
  /// the last-known relay state. Momentary pulses report true then false since
  /// they run through [relayClose] + [relayOpen] internally.
  final void Function(int relay, bool closed)? onState;

  /// How many times to retry a failed momentary OPEN before giving up.
  static const int _openRetries = 2;

  // --- Wire format (verified against CE-Series manual) ----------------------

  /// Close/engage (ON): relay state = true.
  String _closeCommand(int relay) => 'set /relay/$relay/state true';

  /// Open (OFF): relay state = false.
  String _openCommand(int relay) => 'set /relay/$relay/state false';

  // --- Public API -----------------------------------------------------------

  /// Energizes (closes) a relay and leaves it closed (latching ON).
  Future<CommandResult> relayClose(int relayNumber) async {
    final r = await _send(_closeCommand(relayNumber));
    if (r.success) onState?.call(relayNumber, true);
    return r;
  }

  /// De-energizes (opens) a relay and leaves it open (latching OFF).
  Future<CommandResult> relayOpen(int relayNumber) async {
    final r = await _send(_openCommand(relayNumber));
    if (r.success) onState?.call(relayNumber, false);
    return r;
  }

  /// Momentary: close → wait [duration] → open.
  ///
  /// Safety (spec §11.4): if the trailing OPEN fails after a successful CLOSE,
  /// we retry up to [_openRetries] times. If it still fails we return a
  /// WARNING result (success=true so the chain isn't treated as a hard crash,
  /// but severity=warning so the UI shows a strong alert telling the operator
  /// to physically check the device).
  Future<CommandResult> relayMomentary(int relayNumber, Duration duration) async {
    final sent = <String>[];

    final close = await relayClose(relayNumber);
    sent.addAll(close.sentCommands);
    if (!close.success) {
      return CommandResult.fail(
        'Relay $relayNumber CLOSE 실패: ${close.message}',
        sentCommands: sent,
      );
    }

    await Future<void>.delayed(duration);

    CommandResult open = await relayOpen(relayNumber);
    sent.addAll(open.sentCommands);
    var attempt = 0;
    while (!open.success && attempt < _openRetries) {
      attempt++;
      open = await relayOpen(relayNumber);
      sent.addAll(open.sentCommands);
    }

    if (!open.success) {
      return CommandResult.warn(
        '경고: Relay $relayNumber OPEN 명령 실패. 장비 상태를 즉시 확인하세요.',
        sentCommands: sent,
      );
    }

    return CommandResult.ok('명령 전송됨', sentCommands: sent);
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
