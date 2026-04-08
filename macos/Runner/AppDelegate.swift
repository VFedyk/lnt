import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  @IBAction func openPreferences(_ sender: Any) {
    for window in NSApp.windows {
      if let vc = window.contentViewController as? FlutterViewController {
        FlutterMethodChannel(name: "lnt/navigation", binaryMessenger: vc.engine.binaryMessenger)
          .invokeMethod("openSettings", arguments: nil)
        return
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
