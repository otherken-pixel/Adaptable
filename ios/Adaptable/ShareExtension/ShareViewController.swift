import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await ingest() }
    }

    private func ingest() async {
        var urlString: String?
        var text: String?
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    urlString = url.absoluteString
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let raw = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                    text = raw as? String
                }
            }
        }
        let defaults = UserDefaults(suiteName: "group.com.adaptable.app")
        defaults?.set(urlString, forKey: "pending.importURL")
        defaults?.set(text, forKey: "pending.importText")
        extensionContext?.completeRequest(returningItems: nil)
    }
}
