import UIKit

/// Keyboard extensions can't call `UIApplication.open` directly, so walk the responder chain
/// to the host application and invoke `open(_:options:completionHandler:)` dynamically.
enum URLOpener {
    private typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void

    static func open(_ url: URL, from responder: UIResponder) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var current: UIResponder? = responder
        while let next = current {
            if let application = next as? UIApplication, application.responds(to: selector),
               let method = application.method(for: selector) {
                let function = unsafeBitCast(method, to: OpenURL.self)
                function(application, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            current = next.next
        }
        return false
    }
}
