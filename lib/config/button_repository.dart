import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/button_config.dart';
import 'default_buttons.dart';

/// Persists the user-editable button list to shared_preferences.
///
/// Stored as a JSON array under one key. If nothing is stored yet (first run)
/// the factory [defaultButtons] are returned. Never throws.
class ButtonRepository {
  static const String _key = 'buttons_v1';

  Future<List<ButtonConfig>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return defaultButtons();
      }
      final list = jsonDecode(raw) as List<dynamic>;
      final buttons = list
          .map((e) => ButtonConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      // If the user deleted everything we still return the empty list (valid).
      return buttons;
    } catch (_) {
      return defaultButtons();
    }
  }

  Future<bool> save(List<ButtonConfig> buttons) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(buttons.map((b) => b.toJson()).toList());
      return prefs.setString(_key, raw);
    } catch (_) {
      return false;
    }
  }

  /// Clears stored buttons so the next [load] returns factory defaults.
  Future<bool> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.remove(_key);
    } catch (_) {
      return false;
    }
  }
}
