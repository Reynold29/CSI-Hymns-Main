import 'package:vibration/vibration.dart';

class HapticFeedbackManager {
  static Future<void> _vibrate(int duration) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: duration);
    }
  }

  static Future<void> lightClick() async {
    await _vibrate(20); // Shorter, crisp feedback for general taps
  }

  static Future<void> mediumClick() async {
    await _vibrate(50); // Slightly longer, more noticeable feedback
  }
} 