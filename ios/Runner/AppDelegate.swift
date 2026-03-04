import UIKit
import Flutter
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase before plugins that might depend on it.
    FirebaseApp.configure()

    // Ensure all Flutter plugins (Firebase, OneSignal, etc.) are registered on iOS.
    GeneratedPluginRegistrant.register(with: self)

    // Needed so notification-related plugins can receive foreground notifications on iOS.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
