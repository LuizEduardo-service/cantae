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
    // "Abrir ajustes" on the room screens (ROOM-20, ROOM-57).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CantaeSystemSettings") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "cantae/system_settings",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openAppSettings",
        let url = URL(string: UIApplication.openSettingsURLString)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url)
      result(nil)
    }
  }
}
