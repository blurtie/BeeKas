import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // lib/data/camera.dart: opens this app's page in Settings after a camera refusal.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BeeKasSettings") {
      FlutterMethodChannel(name: "beekas/settings", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "openAppSettings",
            let url = URL(string: UIApplication.openSettingsURLString)
          else { return result(FlutterMethodNotImplemented) }
          UIApplication.shared.open(url)
          result(nil)
        }
    }
  }
}
