import ActivityKit
import Foundation
import Observation

@MainActor @Observable final class LiveActivityService {
    private(set) var status = String(localized: "Live Activity has not started yet.")
    private var currentID: String?
    private var syncTail: Task<Void, Never>?
    private var syncGeneration = 0
    func sync(values: SlateValues, enabled: Bool, allowStart: Bool) async {
        syncGeneration += 1
        let generation = syncGeneration
        let previous = syncTail
        let operation = Task<Void, Never> { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            await self.applySync(values: values, enabled: enabled, allowStart: allowStart)
        }
        syncTail = operation
        await operation.value
        if syncGeneration == generation { syncTail = nil }
    }
    private func applySync(values: SlateValues, enabled: Bool, allowStart: Bool) async {
        let all = Activity<SlateActivityAttributes>.activities
        if !enabled {
            await LiveActivityAPI.endAll()
            currentID = nil
            status = String(localized: "Live Activities are off.")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = String(localized: "Live Activities are disabled in iOS Settings.")
            return
        }
        let state = SlateActivityAttributes.ContentState(production: ActivityPayloadText.limited(values.production, bytes: 240),
                    scene: ActivityPayloadText.limited(values.scene, bytes: 40), shot: ActivityPayloadText.limited(values.shot, bytes: 40), take: ActivityPayloadText.limited(values.take, bytes: 40),
                    message: nil, updatedAt: .now)
        let content = ActivityContent(state: state, staleDate: nil)
        let active = all.first { ($0.id == currentID) && ($0.activityState == .active || $0.activityState == .stale) }
            ?? all.first { $0.activityState == .active || $0.activityState == .stale }
        if let active {
            currentID = active.id
            await LiveActivityAPI.update(id: active.id, content: content)
            status = String(localized: "Live Activity is active. Visibility and duration are managed by iOS.")
        } else if allowStart {
            do {
                currentID = try Activity<SlateActivityAttributes>.request(attributes: SlateActivityAttributes(), content: content, pushType: nil).id
                status = String(localized: "Live Activity is active. Visibility and duration are managed by iOS.")
            } catch {
                status = String(localized: "Live Activity could not start. Check iOS settings and widget signing.")
            }
        }
    }
    func showFailure(_ message: String) async {
        status = message
        await LiveActivityAPI.showFailure(message)
    }
}

/// Only Sendable IDs/content cross executors. SDK Activity handles are acquired and used on the same executor.
private enum LiveActivityAPI {
    nonisolated static func update(id: String, content: ActivityContent<SlateActivityAttributes.ContentState>) async {
        guard let activity = Activity<SlateActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(content, alertConfiguration: nil, timestamp: content.state.updatedAt)
    }
    nonisolated static func endAll() async {
        for activity in Activity<SlateActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
    nonisolated static func showFailure(_ message: String) async {
        for activity in Activity<SlateActivityAttributes>.activities where activity.activityState == .active || activity.activityState == .stale {
            var state = activity.content.state
            state.message = ActivityPayloadText.limited(message, bytes: 160); state.updatedAt = .now
            await activity.update(ActivityContent(state: state, staleDate: nil), alertConfiguration: nil, timestamp: state.updatedAt)
        }
    }
}
