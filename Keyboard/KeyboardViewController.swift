import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private lazy var model = KeyboardModel(controller: self)
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        let height = view.heightAnchor.constraint(equalToConstant: 260)
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        model.deactivate()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        model.showsGlobeKey = needsInputModeSwitchKey
    }

    /// Bundle ID of the app being typed into, when iOS exposes it; used to jump back after starting the mic.
    var hostBundleID: String? {
        let key = "_hostBundleID"
        guard let parent, parent.responds(to: NSSelectorFromString(key)),
              let value = parent.value(forKey: key) as? String, !value.isEmpty, value != "<null>" else { return nil }
        return value
    }

    func openContainingApp(_ url: URL) -> Bool {
        URLOpener.open(url, from: self)
    }
}
