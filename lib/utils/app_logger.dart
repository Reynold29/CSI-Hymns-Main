import 'package:flutter/foundation.dart';

/// Centralized app logging. Only outputs in debug mode by default;
/// in release, only [error] and [warning] are written (no verbose/info).
/// Use a [tag] so logs are filterable (e.g. 'Supabase', 'OneSignal').
class AppLogger {
  AppLogger._();

  static const String _tagSeparator = ' | ';

  static void fine(String tag, String message) {
    if (kDebugMode) {
      debugPrint('$tag$_tagSeparator$message');
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('$tag$_tagSeparator$message');
    }
  }

  static void warning(String tag, String message) {
    debugPrint('$tag$_tagSeparator[WARN] $message');
  }

  static void error(String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | $error');
    if (stackTrace != null && kDebugMode) buffer.write('\n$stackTrace');
    debugPrint('$tag$_tagSeparator[ERROR] $buffer');
  }
}
