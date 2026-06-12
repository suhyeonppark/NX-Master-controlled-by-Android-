import '../actions/action_models.dart';

enum ButtonScreen { relay, ir, serial, io }

enum ButtonType { relay, ir, serial, io }

class ButtonConfig {
  const ButtonConfig({
    required this.id,
    required this.label,
    required this.screen,
    required this.group,
    required this.type,
    this.order = 0,
    this.confirm = false,
    this.danger = false,
    this.relay = 1,
    this.relayMode = RelayMode.latchClose,
    this.durationMs = 500,
    this.irPort = 1,
    this.irCh = 1,
    this.serialPort = 1,
    this.serialMessage = '',
    this.ioPort = 1,
    this.ioCh = 1,
    this.ioValue = 1,
  });

  final String id;
  final String label;
  final ButtonScreen screen;
  final String group;
  final int order;
  final ButtonType type;
  final bool confirm;
  final bool danger;

  final int relay;
  final RelayMode relayMode;
  final int durationMs;

  final int irPort;
  final int irCh;

  final int serialPort;
  final String serialMessage;

  final int ioPort;
  final int ioCh;
  final int ioValue;

  String get _confirmMessage => "'$label'을(를) 실행하시겠습니까?";

  ActionDef toActionDef() {
    switch (type) {
      case ButtonType.relay:
        return RelayAction(
          id: id,
          ch: relay,
          mode: relayMode,
          durationMs: durationMs,
          confirm: confirm,
          confirmMessage: confirm ? _confirmMessage : null,
        );
      case ButtonType.ir:
        return IrAction(
          id: id,
          irPort: irPort,
          ch: irCh,
          confirm: confirm,
          confirmMessage: confirm ? _confirmMessage : null,
        );
      case ButtonType.serial:
        return SerialAction(
          id: id,
          port: serialPort,
          message: serialMessage,
          confirm: confirm,
          confirmMessage: confirm ? _confirmMessage : null,
        );
      case ButtonType.io:
        return IoAction(
          id: id,
          port: ioPort,
          ch: ioCh,
          value: ioValue,
          confirm: confirm,
          confirmMessage: confirm ? _confirmMessage : null,
        );
    }
  }

  ButtonConfig copyWith({
    String? label,
    ButtonScreen? screen,
    String? group,
    int? order,
    ButtonType? type,
    bool? confirm,
    bool? danger,
    int? relay,
    RelayMode? relayMode,
    int? durationMs,
    int? irPort,
    int? irCh,
    int? serialPort,
    String? serialMessage,
    int? ioPort,
    int? ioCh,
    int? ioValue,
  }) {
    return ButtonConfig(
      id: id,
      label: label ?? this.label,
      screen: screen ?? this.screen,
      group: group ?? this.group,
      order: order ?? this.order,
      type: type ?? this.type,
      confirm: confirm ?? this.confirm,
      danger: danger ?? this.danger,
      relay: relay ?? this.relay,
      relayMode: relayMode ?? this.relayMode,
      durationMs: durationMs ?? this.durationMs,
      irPort: irPort ?? this.irPort,
      irCh: irCh ?? this.irCh,
      serialPort: serialPort ?? this.serialPort,
      serialMessage: serialMessage ?? this.serialMessage,
      ioPort: ioPort ?? this.ioPort,
      ioCh: ioCh ?? this.ioCh,
      ioValue: ioValue ?? this.ioValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'screen': screen.name,
        'group': group,
        'order': order,
        'type': type.name,
        'confirm': confirm,
        'danger': danger,
        'relay': relay,
        'relayMode': relayMode.name,
        'durationMs': durationMs,
        'irPort': irPort,
        'irCh': irCh,
        'serialPort': serialPort,
        'serialMessage': serialMessage,
        'ioPort': ioPort,
        'ioCh': ioCh,
        'ioValue': ioValue,
      };

  factory ButtonConfig.fromJson(Map<String, dynamic> j) {
    final type = _enumByName(ButtonType.values, j['type'], ButtonType.ir);
    return ButtonConfig(
      id: j['id'] as String,
      label: j['label'] as String? ?? '',
      screen: _enumByName(
        ButtonScreen.values,
        j['screen'],
        _screenForType(type),
      ),
      group: j['group'] as String? ?? '',
      order: (j['order'] as num?)?.toInt() ?? 0,
      type: type,
      confirm: (j['confirm'] as bool? ?? false) ||
          ((j['holdMs'] as num?)?.toInt() ?? 0) > 0,
      danger: j['danger'] as bool? ?? false,
      relay: (j['relay'] as num?)?.toInt() ?? 1,
      relayMode:
          _enumByName(RelayMode.values, j['relayMode'], RelayMode.latchClose),
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 500,
      irPort: (j['irPort'] as num?)?.toInt() ?? 1,
      irCh: (j['irCh'] as num?)?.toInt() ??
          (j['irNumber'] as num?)?.toInt() ??
          1,
      serialPort: (j['serialPort'] as num?)?.toInt() ?? 1,
      serialMessage: j['serialMessage'] as String? ?? '',
      ioPort: (j['ioPort'] as num?)?.toInt() ?? 1,
      ioCh: (j['ioCh'] as num?)?.toInt() ?? 1,
      ioValue: (j['ioValue'] as num?)?.toInt() ?? 1,
    );
  }

  static ButtonScreen _screenForType(ButtonType type) => switch (type) {
        ButtonType.relay => ButtonScreen.relay,
        ButtonType.ir => ButtonScreen.ir,
        ButtonType.serial => ButtonScreen.serial,
        ButtonType.io => ButtonScreen.io,
      };

  static T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    return fallback;
  }
}
