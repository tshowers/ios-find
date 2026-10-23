import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Find this" in the share sheet: Find's answer for the selected text (or
/// the shared page's title), right there in the sheet.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await model.start(with: extensionContext?.inputItems as? [NSExtensionItem] ?? []) }
    }
}
