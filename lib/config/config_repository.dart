import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Persists [AppConfig] across app restarts using shared_preferences.
///
/// Stored as a single JSON string under one key so the schema can evolve
/// without juggling many keys.
class ConfigRepository {
  static const String _key = 'app_config_v1';

  /// Loads the saved config, or returns defaults if nothing was stored / the
  /// stored value is corrupt. Never throws.
  Future<AppConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return const AppConfig();
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (_) {
      // Corrupt or unreadable settings should never block startup.
      return const AppConfig();
    }
  }

  /// Saves the config. Returns true on success.
  Future<bool> save(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(_key, jsonEncode(config.toJson()));
    } catch (_) {
      return false;
    }
  }
}
