import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // The most recent APNs registration outcome. Surfaced to Dart over a method
  // channel for in-app diagnostics, because reading the device console requires
  // a Mac and OOTT is built/shipped via Codemagic + TestFlight.
  private var apnsStatus = "APNs: registration not completed yet"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "oott/push_diagnostics",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "apnsStatus" {
          result(self?.apnsStatus ?? "APNs: status unavailable")
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Logged for diagnostics; super still forwards the token to the
  // firebase_messaging plugin (method swizzling is enabled).
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsStatus = "APNs: registered OK (token bytes=\(deviceToken.count))"
    NSLog("[OOTT] \(apnsStatus)")
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // This fires instead of the success callback when iOS refuses to issue an APNs
  // token; error.localizedDescription is the reason we need (e.g. "no valid
  // 'aps-environment' entitlement string found for application").
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsStatus = "APNs: registration FAILED - \(error.localizedDescription)"
    NSLog("[OOTT] \(apnsStatus)")
    super.application(
      application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
