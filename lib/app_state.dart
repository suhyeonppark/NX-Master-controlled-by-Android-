import 'dart:async';

import 'package:flutter/widgets.dart';

import 'actions/action_ids.dart';
import 'actions/action_models.dart';
import 'actions/action_router.dart';
import 'actions/interlock_manager.dart';
import 'ce/wol_client.dart';
import 'config/app_config.dart';
import 'config/button_repository.dart';
import 'config/config_repository.dart';
import 'config/macro_repository.dart';
import 'models/button_config.dart';
import 'models/macro_config.dart';
import 'models/command_result.dart';
import 'models/device_status.dart';
import 'nx/device_state_store.dart';
import 'nx/feedback_parser.dart';
import 'nx/nx_connection.dart';

class AppState extends ChangeNotifier {
  AppState({
    ConfigRepository? repository,
    ButtonRepository? buttonRepository,
    MacroRepository? macroRepository,
  })  : _repo = repository ?? ConfigRepository(),
        _buttonRepo = buttonRepository ?? ButtonRepository(),
        _macroRepo = macroRepository ?? MacroRepository() {
    _deviceStates.addListener(notifyListeners);
    _nx = NxConnection(config: () => _config.nx, onFeedback: _onFeedback)
      ..addListener(notifyListeners);
    router = ActionRouter(
      nx: _nx,
      interlock: InterlockManager(_nx),
      wol: WolClient(),
      resolve: (id) => _actionMap[id],
    );
  }

  final ConfigRepository _repo;
  final ButtonRepository _buttonRepo;
  final MacroRepository _macroRepo;
  final DeviceStateStore _deviceStates = DeviceStateStore();
  late final NxConnection _nx;
  late final ActionRouter router;

  AppConfig _config = const AppConfig();
  AppConfig get config => _config;

  DeviceStatus get nxStatus => _nx.status;

  List<ButtonConfig> _buttons = const [];
  List<ButtonConfig> get buttons => List.unmodifiable(_buttons);

  List<MacroConfig> _macros = const [];
  List<MacroConfig> get macros => List.unmodifiable(_macros);

  Map<String, ActionDef> _actionMap = {};

  bool _busy = false;
  bool get isBusy => _busy;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  void _rebuildActionMap() {
    final map = <String, ActionDef>{};
    for (final b in _buttons) {
      map[b.id] = b.toActionDef();
    }
    for (final m in _macros) {
      map[m.id] = m.toActionDef();
    }
    for (final pc in _config.pcs) {
      map[ActionIds.wol(pc.id)] =
          WolAction(id: ActionIds.wol(pc.id), mac: pc.mac, name: pc.name);
    }
    map[ActionIds.wolAll] = MacroAction(
      id: ActionIds.wolAll,
      confirm: false,
      steps: [
        for (final pc in _config.pcs)
          MacroStep(ActionIds.wol(pc.id), delayAfterMs: 150),
      ],
    );
    _actionMap = map;
  }

  Map<String, List<ButtonConfig>> buttonsByGroup(ButtonScreen screen) {
    final result = <String, List<ButtonConfig>>{};
    final filtered = _buttons.where((b) => b.screen == screen).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final b in filtered) {
      result.putIfAbsent(b.group, () => []).add(b);
    }
    return result;
  }

  bool? relayIsOn(int relay) => _deviceStates.relay(relay);
  bool? ioIsOn(int port, int ch) => _deviceStates.io(port, ch);
  String? serialMessage(int port) => _deviceStates.serial(port);

  void _onFeedback(NxFeedback feedback) {
    switch (feedback) {
      case RelayFeedback():
        _deviceStates.setRelay(feedback.ch, feedback.value);
      case IoFeedback():
        _deviceStates.setIo(feedback.port, feedback.ch, feedback.value);
      case SerialFeedback():
        _deviceStates.setSerial(feedback.port, feedback.message);
    }
  }

  Future<void> init() async {
    _config = await _repo.load();
    _buttons = await _buttonRepo.load();
    _macros = await _macroRepo.load();
    _rebuildActionMap();
    _loaded = true;
    notifyListeners();
    _nx.start();
  }

  Future<bool> _persistButtons() async {
    _rebuildActionMap();
    notifyListeners();
    return _buttonRepo.save(_buttons);
  }

  Future<bool> addButton(ButtonConfig button) {
    final maxOrder = _buttons.isEmpty
        ? 0
        : _buttons.map((b) => b.order).reduce((a, b) => a > b ? a : b);
    _buttons = [..._buttons, button.copyWith(order: maxOrder + 1)];
    return _persistButtons();
  }

  Future<bool> updateButton(ButtonConfig button) {
    _buttons = [
      for (final b in _buttons)
        if (b.id == button.id) button else b,
    ];
    return _persistButtons();
  }

  Future<bool> deleteButton(String id) {
    _buttons = [
      for (final b in _buttons)
        if (b.id != id) b,
    ];
    return _persistButtons();
  }

  Future<bool> resetButtons() async {
    await _buttonRepo.reset();
    _buttons = await _buttonRepo.load();
    return _persistButtons();
  }

  String newButtonId() => 'btn_${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> _persistMacros() async {
    _rebuildActionMap();
    notifyListeners();
    return _macroRepo.save(_macros);
  }

  Future<bool> addMacro(MacroConfig macro) {
    _macros = [..._macros, macro];
    return _persistMacros();
  }

  Future<bool> updateMacro(MacroConfig macro) {
    _macros = [
      for (final m in _macros)
        if (m.id == macro.id) macro else m,
    ];
    return _persistMacros();
  }

  Future<bool> deleteMacro(String id) {
    _macros = [
      for (final m in _macros)
        if (m.id != id) m,
    ];
    return _persistMacros();
  }

  Future<bool> resetMacros() async {
    await _macroRepo.reset();
    _macros = await _macroRepo.load();
    return _persistMacros();
  }

  String newMacroId() => 'macro_${DateTime.now().microsecondsSinceEpoch}';

  void unawaitedTest() {
    unawaited(testNx());
  }

  Future<bool> saveConfig(AppConfig newConfig) async {
    _config = newConfig;
    _deviceStates.clearDigitalStates();
    _rebuildActionMap();
    notifyListeners();
    _nx.restart();
    return _repo.save(newConfig);
  }

  Future<DeviceStatus> testNx({String? hostOverride, int? portOverride}) async {
    final result = await _nx.testConnection(
      hostOverride: hostOverride,
      portOverride: portOverride,
    );
    return DeviceStatus(
      state: result.success
          ? DeviceConnectionState.online
          : DeviceConnectionState.offline,
      detail: result.success ? null : result.message,
    );
  }

  Future<CommandResult> runAction(String actionId) async {
    final isMacro = router.lookup(actionId) is MacroAction;
    if (isMacro) {
      _busy = true;
      notifyListeners();
    }
    try {
      return await router.run(actionId);
    } finally {
      if (isMacro) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _nx.dispose();
    _deviceStates.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
