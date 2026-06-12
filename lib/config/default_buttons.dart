import '../actions/action_ids.dart';
import '../actions/action_models.dart';
import '../models/button_config.dart';

List<ButtonConfig> defaultButtons() {
  var order = 0;
  final list = <ButtonConfig>[];

  ButtonConfig relay(
    String id,
    String group,
    String label,
    int ch,
    RelayMode mode, {
    bool danger = false,
    bool confirm = false,
  }) =>
      ButtonConfig(
        id: id,
        label: label,
        screen: ButtonScreen.relay,
        group: group,
        order: order++,
        type: ButtonType.relay,
        relay: ch,
        relayMode: mode,
        danger: danger,
        confirm: confirm,
      );

  ButtonConfig ir(String id, String group, String label, int port, int ch) =>
      ButtonConfig(
        id: id,
        label: label,
        screen: ButtonScreen.ir,
        group: group,
        order: order++,
        type: ButtonType.ir,
        irPort: port,
        irCh: ch,
      );

  list.addAll([
    relay(ActionIds.seq1On, 'Relay', 'Relay 1 ON', 1, RelayMode.latchClose),
    relay(ActionIds.seq1Off, 'Relay', 'Relay 1 OFF', 1, RelayMode.latchOpen,
        danger: true, confirm: true),
    relay(ActionIds.seq2On, 'Relay', 'Relay 2 ON', 2, RelayMode.latchClose),
    relay(ActionIds.seq2Off, 'Relay', 'Relay 2 OFF', 2, RelayMode.latchOpen,
        danger: true, confirm: true),
    ir(ActionIds.tv1PowerOn, 'IR Port 1', 'IR 1-1', 1, 1),
    ir(ActionIds.tv1PowerOff, 'IR Port 1', 'IR 1-2', 1, 2),
    ir(ActionIds.tv2PowerOn, 'IR Port 2', 'IR 2-1', 2, 1),
    ir(ActionIds.tv2PowerOff, 'IR Port 2', 'IR 2-2', 2, 2),
    ButtonConfig(
      id: 'serial_1_power_on',
      label: 'Serial 1 PWR ON',
      screen: ButtonScreen.serial,
      group: 'Serial Port 1',
      order: order++,
      type: ButtonType.serial,
      serialPort: 1,
      serialMessage: 'PWR ON',
    ),
    ButtonConfig(
      id: 'io_1_1_on',
      label: 'IO 1-1 ON',
      screen: ButtonScreen.io,
      group: 'IO Port 1',
      order: order++,
      type: ButtonType.io,
      ioPort: 1,
      ioCh: 1,
      ioValue: 1,
    ),
    ButtonConfig(
      id: 'io_1_1_off',
      label: 'IO 1-1 OFF',
      screen: ButtonScreen.io,
      group: 'IO Port 1',
      order: order++,
      type: ButtonType.io,
      ioPort: 1,
      ioCh: 1,
      ioValue: 0,
      danger: true,
    ),
  ]);

  return list;
}
