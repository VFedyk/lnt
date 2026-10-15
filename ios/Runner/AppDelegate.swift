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

  private var systemDictionaryChannel: FlutterMethodChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // If there is no registrar, the Dart side's MissingPluginException path
    // shows an error SnackBar.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LntSystemDictionary") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "lnt/system_dictionary",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "lookUp" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let word = call.arguments as? String, !word.isEmpty else {
        result(FlutterError(code: "BAD_ARGS", message: "Expected a non-empty word", details: nil))
        return
      }
      guard let presenter = AppDelegate.topViewController() else {
        result(FlutterError(code: "NO_PRESENTER", message: "No view controller to present from", details: nil))
        return
      }
      let controller = UIReferenceLibraryViewController(term: word)
      if UIDevice.current.userInterfaceIdiom == .pad {
        controller.modalPresentationStyle = .formSheet
      }
      presenter.present(controller, animated: true)
      result(nil)
    }
    systemDictionaryChannel = channel
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive }
    let window = scene?.windows.first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
