import ActivityKit
import Foundation

/// Owns the Live Activity that is up while the microphone is on (spec 009, FR-009-4).
@MainActor
final class DictationActivity {
    typealias State = DictationActivityAttributes.ContentState

    private var activity: Activity<DictationActivityAttributes>?
    private var shown: State?
    private var watcher: Task<Void, Never>?
    private var queue: Task<Void, Never>?
    private var dismissedByUser = false

    /// Called when the Live Activity is swiped away or ended by the system.
    var onDismissed: (() -> Void)?
    /// Why iOS refused the last request, for the start log.
    private(set) var lastError: String?

    init() {
        // An activity left over from a previous launch no longer has a microphone behind it.
        for stale in Activity<DictationActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Shows or updates the activity. False means iOS refused to start one, which happens on some background launches.
    @discardableResult
    func show(_ state: State) -> Bool {
        guard !dismissedByUser else { return false }
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            guard state != shown else { return true }
            shown = state
            enqueue { await activity.update(content) }
            return true
        }
        do {
            let started = try Activity.request(attributes: DictationActivityAttributes(), content: content)
            activity = started
            shown = state
            lastError = nil
            watch(started)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func end() {
        watcher?.cancel()
        watcher = nil
        dismissedByUser = false
        guard let activity else { return }
        self.activity = nil
        shown = nil
        enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Updates reach the system in the order they were made.
    private func enqueue(_ work: @escaping () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await work()
        }
    }

    private func watch(_ started: Activity<DictationActivityAttributes>) {
        watcher = Task { [weak self] in
            for await state in started.activityStateUpdates where state == .dismissed || state == .ended {
                guard let self, !Task.isCancelled, self.activity?.id == started.id else { return }
                self.activity = nil
                self.shown = nil
                self.dismissedByUser = true
                self.onDismissed?()
                return
            }
        }
    }
}
