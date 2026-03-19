import 'package:vibration/vibration.dart';
import 'dart:async';

class HapticFeedbackManager {
  static DateTime? _last;
  static const _minIntervalMs = 30; // throttle to avoid stacking

  static Future<void> _vibrate({int durationMs = 20, int? amplitude}) async {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!).inMilliseconds < _minIntervalMs)
      return;
    _last = now;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // On Android, amplitude 1-255. iOS ignores amplitude but keeps duration crisp.
      if (amplitude != null) {
        await Vibration.vibrate(duration: durationMs, amplitude: amplitude);
      } else {
        await Vibration.vibrate(duration: durationMs);
      }
    }
  }

  static Future<void> lightClick() async {
    await _vibrate(durationMs: 18, amplitude: 40);
  }

  static Future<void> mediumClick() async {
    await _vibrate(durationMs: 35, amplitude: 90);
  }

  static Future<void> success() async {
    await Vibration.vibrate(pattern: [0, 16, 30, 22], intensities: [40, 90]);
  }

  static Future<void> error() async {
    await Vibration.vibrate(
        pattern: [0, 22, 30, 22, 30, 22], intensities: [120, 120, 120]);
  }
}
