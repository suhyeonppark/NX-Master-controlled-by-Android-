enum RelayMode {
  momentary,
  latchClose,
  latchOpen,
}

sealed class ActionDef {
  const ActionDef({
    required this.id,
    required this.confirm,
    this.confirmMessage,
  });

  final String id;
  final bool confirm;
  final String? confirmMessage;
}

class IrAction extends ActionDef {
  const IrAction({
    required super.id,
    required this.irPort,
    required this.ch,
    super.confirm = false,
    super.confirmMessage,
  });

  final int irPort;
  final int ch;
}

class RelayAction extends ActionDef {
  const RelayAction({
    required super.id,
    required this.ch,
    required this.mode,
    this.durationMs = 500,
    this.openBeforeClose = const [],
    super.confirm = false,
    super.confirmMessage,
  });

  final int ch;
  final RelayMode mode;
  final int durationMs;
  final List<int> openBeforeClose;

  Duration get duration => Duration(milliseconds: durationMs);
}

class SerialAction extends ActionDef {
  const SerialAction({
    required super.id,
    required this.port,
    required this.message,
    super.confirm = false,
    super.confirmMessage,
  });

  final int port;
  final String message;
}

class IoAction extends ActionDef {
  const IoAction({
    required super.id,
    required this.port,
    required this.ch,
    required this.value,
    super.confirm = false,
    super.confirmMessage,
  });

  final int port;
  final int ch;
  final int value;
}

class WolAction extends ActionDef {
  const WolAction({
    required super.id,
    required this.mac,
    required this.name,
    super.confirm = false,
    super.confirmMessage,
  });

  final String mac;
  final String name;
}

class MacroStep {
  const MacroStep(this.actionId, {this.delayAfterMs = 0});

  final String actionId;
  final int delayAfterMs;
}

class MacroAction extends ActionDef {
  const MacroAction({
    required super.id,
    required this.steps,
    super.confirm = false,
    super.confirmMessage,
  });

  final List<MacroStep> steps;
}
