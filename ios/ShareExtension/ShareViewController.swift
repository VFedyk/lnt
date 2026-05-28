import UIKit
import Social
import MobileCoreServices

/// Receives a shared URL, stores it in the App Group UserDefaults using the
/// same format that receive_sharing_intent expects, then opens the host app.
class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool { true }
    override func didSelectPost() { }
    override func configurationItems() -> [Any]! { [] }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let extBundleId = Bundle.main.bundleIdentifier ?? ""
        // Derive host bundle ID: strip last ".<ExtensionName>" component.
        let hostBundleId = extBundleId
            .components(separatedBy: ".")
            .dropLast()
            .joined(separator: ".")
        let appGroupId = "group.\(hostBundleId)"

        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachment = item.attachments?.first
        else {
            complete()
            return
        }

        let typeId = "public.url"
        guard attachment.hasItemConformingToTypeIdentifier(typeId) else {
            complete()
            return
        }

        attachment.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] data, _ in
            guard let self = self, let url = data as? URL else {
                self?.complete()
                return
            }

            // Write JSON in the format receive_sharing_intent expects:
            // [{"path": "<url>", "type": "url"}]
            let entry: [String: Any] = ["path": url.absoluteString, "type": "url"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: [entry]) {
                UserDefaults(suiteName: appGroupId)?.set(jsonData, forKey: "ShareKey")
            }

            // Bring the host app to foreground using its registered URL scheme.
            if let redirectURL = URL(string: "ShareMedia-\(hostBundleId):share") {
                var responder: UIResponder? = self
                while let current = responder {
                    if let application = current as? UIApplication {
                        if #available(iOS 18.0, *) {
                            application.open(redirectURL, options: [:], completionHandler: nil)
                        } else {
                            let sel = sel_registerName("openURL:")
                            _ = application.perform(sel, with: redirectURL)
                        }
                        break
                    }
                    responder = current.next
                }
            }

            self.complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
