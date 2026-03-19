import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service that manages the Christmas mode feature flag.
///
/// The flag can be controlled via:
/// 1. Remote config from Supabase (preferred)
/// 2. Local SharedPreferences fallback
/// 3. Manual override for testing
///
/// When `isChristmasTime` is true, the app shows Christmas-themed UI
/// with category cards for Common Hymns and Christmas Carols.
class ChristmasModeService with ChangeNotifier {
  static const String _localKey = 'is_christmas_time';
  static const String _remoteConfigTable = 'app_config';

  bool _isChristmasTime = false;
  bool _isLoading = true; // true until deferred _loadChristmasMode completes
  bool _hasError = false;

  bool get isChristmasTime => _isChristmasTime;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  ChristmasModeService() {
    // Defer remote fetch to after first frame so first paint is not blocked.
    SchedulerBinding.instance.addPostFrameCallback((_) => _loadChristmasMode());
  }

  Future<void> _loadChristmasMode() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      // Try remote config first
      final remoteValue = await _fetchRemoteConfig();
      if (remoteValue != null) {
        _isChristmasTime = remoteValue;
        // Cache locally for offline use
        await _saveLocalConfig(remoteValue);
      } else {
        // Fall back to local config
        _isChristmasTime = await _loadLocalConfig();
      }
    } catch (e) {
      debugPrint('ChristmasModeService: Error loading config: $e');
      _hasError = true;
      // Fall back to local config on error
      _isChristmasTime = await _loadLocalConfig();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches the Christmas mode flag from Supabase app_config table.
  /// Returns null if not available or on error.
  Future<bool?> _fetchRemoteConfig() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from(_remoteConfigTable)
          .select('value')
          .eq('key', 'is_christmas_time')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final value = response['value'];
        if (value is bool) return value;
        if (value is int) return value == 1;
        if (value is String)
          return value == '1' || value.toLowerCase() == 'true';
      }
      return null;
    } catch (e) {
      debugPrint('ChristmasModeService: Remote config fetch failed: $e');
      return null;
    }
  }

  Future<bool> _loadLocalConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_localKey) ?? _autoDetectChristmasSeason();
    } catch (e) {
      return _autoDetectChristmasSeason();
    }
  }

  Future<void> _saveLocalConfig(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localKey, value);
    } catch (e) {
      debugPrint('ChristmasModeService: Failed to save local config: $e');
    }
  }

  /// Auto-detect Christmas season (December 1 - January 6)
  bool _autoDetectChristmasSeason() {
    final now = DateTime.now();
    // December or early January (up to Epiphany)
    return now.month == 12 || (now.month == 1 && now.day <= 6);
  }

  /// Manually set Christmas mode (for testing/admin purposes)
  Future<void> setChristmasMode(bool enabled) async {
    _isChristmasTime = enabled;
    await _saveLocalConfig(enabled);
    notifyListeners();
  }

  /// Refresh the config from remote
  Future<void> refresh() async {
    await _loadChristmasMode();
  }

  /// Toggle Christmas mode
  Future<void> toggle() async {
    await setChristmasMode(!_isChristmasTime);
  }
}
