import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var systemDictionaryChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "lnt/system_dictionary",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak flutterViewController] call, result in
      guard call.method == "lookUp" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let word = call.arguments as? String, !word.isEmpty else {
        result(FlutterError(code: "BAD_ARGS", message: "Expected a non-empty word", details: nil))
        return
      }
      guard let view = flutterViewController?.view else {
        result(nil)
        return
      }
      let attributed = NSAttributedString(
        string: word,
        attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
      )
      view.showDefinition(
        for: attributed,
        at: NSPoint(x: view.bounds.midX, y: view.bounds.midY)
      )
      result(nil)
    }
    systemDictionaryChannel = channel

    super.awakeFromNib()
  }
}
