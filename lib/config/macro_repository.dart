import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/macro_config.dart';
import 'default_macros.dart';

/// Persists the user-editable macro list to shared_preferences.
///
/// Mirrors `ButtonRepository`. Stored as a JSON array under one key. If nothing
/// is stored yet (first run) the factory [defaultMacros] are returned. Never
/// throws.
class MacroRepository {
  static const String _key = 'macros_v1';

  Future<List<MacroConfig>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return defaultMacros();
      }
      final list = jsonDecode(raw) as List<dynamic>;
      // If the user deleted everything we still return the empty list (valid).
      return list
          .map((e) => MacroConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return defaultMacros();
    }
  }

  Future<bool> save(List<MacroConfig> macros) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(macros.map((m) => m.toJson()).toList());
      return prefs.setString(_key, raw);
    } catch (_) {
      return false;
    }
  }

  /// Clears stored macros so the next [load] returns factory defaults.
  Future<bool> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.remove(_key);
    } catch (_) {
      return false;
    }
  }
}
