import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    AppDelegate.observeCapture()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "dijigoo/privacy",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "setSecure" {
        let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
        AppDelegate.setScreenSecure(on)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static var privacyOverlay: UIView?
  private static var secureWanted = false
  private static var observersReady = false

  static func setScreenSecure(_ on: Bool) {
    DispatchQueue.main.async {
      secureWanted = on
      applyOverlay()
    }
  }

  private static func observeCapture() {
    guard !observersReady else { return }
    observersReady = true
    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in applyOverlay() }
    NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { _ in applyOverlay() }
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { _ in applyOverlay() }
  }

  private static func applyOverlay() {
    guard let window = keyWindow else { return }
    let captured = UIScreen.main.isCaptured
    let background = UIApplication.shared.applicationState != .active
    let hide = secureWanted && (captured || background)
    if hide {
      if privacyOverlay == nil {
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        overlay.accessibilityViewIsModal = true
        window.addSubview(overlay)
        privacyOverlay = overlay
      }
    } else {
      privacyOverlay?.removeFromSuperview()
      privacyOverlay = nil
    }
  }

  private static var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
