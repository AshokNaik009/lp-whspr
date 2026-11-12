import Foundation

/// Cross-process signals between the app and its extensions. Payloads travel through `SharedStore`.
enum DarwinSignal: String {
    case command = "com.leapwhisper.command"
    case state = "com.leapwhisper.state"
    case transcript = "com.leapwhisper.transcript"
    case pendingStart = "com.leapwhisper.pendingStart"
}

final class DarwinNotifier {
    static let shared = DarwinNotifier()

    private var handlers: [String: [UUID: () -> Void]] = [:]
    private let lock = NSLock()

    func post(_ signal: DarwinSignal) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(signal.rawValue as CFString), nil, nil, true)
    }

    @discardableResult
    func observe(_ signal: DarwinSignal, handler: @escaping () -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        let isFirst = handlers[signal.rawValue] == nil
        handlers[signal.rawValue, default: [:]][token] = handler
        lock.unlock()

        if isFirst {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            let observer = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterAddObserver(center, observer, { _, observer, name, _, _ in
                guard let observer, let name else { return }
                let notifier = Unmanaged<DarwinNotifier>.fromOpaque(observer).takeUnretainedValue()
                notifier.dispatch(name.rawValue as String)
            }, signal.rawValue as CFString, nil, .deliverImmediately)
        }
        return token
    }

    func removeObserver(_ token: UUID) {
        lock.lock()
        for key in handlers.keys { handlers[key]?[token] = nil }
        lock.unlock()
    }

    private func dispatch(_ name: String) {
        lock.lock()
        let callbacks = handlers[name].map { Array($0.values) } ?? []
        lock.unlock()
        DispatchQueue.main.async { callbacks.forEach { $0() } }
    }
}
