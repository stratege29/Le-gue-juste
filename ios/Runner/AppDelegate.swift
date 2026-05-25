import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register for remote notifications EARLY so an APNs token is available
    // before the user tries phone auth. The firebase_auth plugin's automatic
    // swizzling will forward the token to FIRAuth so Firebase Phone Auth can
    // use silent push verification (avoiding the reCAPTCHA fallback that was
    // failing with "internal-error"). No manual setAPNSToken needed.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
