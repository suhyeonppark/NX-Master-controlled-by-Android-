import '../models/command_result.dart';
import '../nx/nx_command.dart';
import '../nx/nx_connection.dart';
import 'action_models.dart';

class InterlockManager {
  InterlockManager(this._nx);

  final NxConnection _nx;

  Future<CommandResult> executeRelay(RelayAction action) async {
    final sent = <String>[];

    for (final ch in action.openBeforeClose) {
      final r = await _nx.send(NxCommand.relay(ch, 0));
      sent.addAll(r.sentCommands);
      if (!r.success) {
        return CommandResult.fail(
          'Interlock 해제 실패 (relay $ch): ${r.message}',
          sentCommands: sent,
        );
      }
    }

    switch (action.mode) {
      case RelayMode.momentary:
        final on = await _nx.send(NxCommand.relay(action.ch, 1));
        sent.addAll(on.sentCommands);
        if (!on.success) {
          return CommandResult.fail(on.message, sentCommands: sent);
        }
        await Future<void>.delayed(action.duration);
        final off = await _nx.send(NxCommand.relay(action.ch, 0));
        sent.addAll(off.sentCommands);
        if (!off.success) {
          return CommandResult.warn(
            '순간 동작 ON 전송 후 OFF 전송 실패: ${off.message}',
            sentCommands: sent,
          );
        }
        return CommandResult.ok('명령 전송됨', sentCommands: sent);
      case RelayMode.latchClose:
        return _withMessage(await _nx.send(NxCommand.relay(action.ch, 1)));
      case RelayMode.latchOpen:
        return _withMessage(await _nx.send(NxCommand.relay(action.ch, 0)));
    }
  }

  CommandResult _withMessage(CommandResult r) {
    if (!r.success) return r;
    return CommandResult.ok('명령 전송됨', sentCommands: r.sentCommands);
  }
}
