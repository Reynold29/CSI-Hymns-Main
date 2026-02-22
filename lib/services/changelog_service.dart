import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/models/changelog_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

class ChangelogService {
  static const String _lastShownVersionKey = 'last_shown_changelog_version';
  static const String _isFirstLaunchKey = 'is_first_app_launch';
  
  String? _cachedVersion;
  
  /// Gets the current app version from package_info
  Future<String> getCurrentVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // Extract version without build number (e.g., "4.1.0-stable" from "4.1.0-stable+23")
      // The version string from package_info is just the version name, not including build number
      final version = packageInfo.version;
      _cachedVersion = version;
      return version;
    } catch (e) {
      // Fallback to a default version
      return '4.1.0-stable';
    }
  }
  
  /// Normalizes version string for comparison (removes any suffixes after +)
  String normalizeVersion(String version) {
    // Remove build number if present (e.g., "4.1.0-stable+23" -> "4.1.0-stable")
    return version.split('+').first;
  }
  
  /// Checks if changelog should be shown
  Future<bool> shouldShowChangelog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShownVersion = prefs.getString(_lastShownVersionKey);
      final currentVersion = await getCurrentVersion();
      final normalizedCurrent = normalizeVersion(currentVersion);
      
      // Show if first launch
      final isFirstLaunch = prefs.getBool(_isFirstLaunchKey) ?? true;
      if (isFirstLaunch) {
        await prefs.setBool(_isFirstLaunchKey, false);
        return true;
      }
      
      // Show if version changed (compare normalized versions)
      if (lastShownVersion == null || normalizeVersion(lastShownVersion) != normalizedCurrent) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Gets the latest changelog entry
  Future<ChangelogEntry?> getLatestChangelog() async {
    try {
      final String jsonData = await rootBundle.loadString(
        'lib/assets/changelog.json',
      );
      final List<dynamic> data = jsonDecode(jsonData);
      
      if (data.isEmpty) return null;
      
      // Get the first (latest) entry
      return ChangelogEntry.fromJson(data[0] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
  
  /// Marks changelog as shown for current version
  Future<void> markChangelogAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = await getCurrentVersion();
      final normalizedVersion = normalizeVersion(currentVersion);
      await prefs.setString(_lastShownVersionKey, normalizedVersion);
    } catch (e) {
      // Ignore errors
    }
  }
}

