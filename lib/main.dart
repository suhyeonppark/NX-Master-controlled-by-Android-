import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Landscape-first for field tablet operation (spec §20). Portrait is still
  // allowed so dev testing / unusual mounts don't break; layouts are scrollable.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Keep the tablet awake while the control app is running (spec §13).
  // Wrapped in try/catch so an unsupported platform never blocks startup.
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  final state = AppState();
  // Load persisted settings before first frame; init also kicks off a probe.
  await state.init();

  runApp(AmxControlApp(state: state));
}
