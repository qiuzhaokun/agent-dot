import Foundation

public struct SessionVisibilityTracker {
    private var missingSince: [String: Int64] = [:]

    public init() {}

    public mutating func evaluate(
        state: SessionState,
        now: Int64,
        isProcessAlive: Bool
    ) -> SessionVisibilityResult {
        let decision = SessionVisibility.evaluate(
            state: state,
            now: now,
            isProcessAlive: isProcessAlive,
            missingSince: missingSince[state.sessionID]
        )

        switch decision {
        case .visible(let nextMissingSince):
            missingSince[state.sessionID] = nextMissingSince
        case .hidden:
            // Keep missingSince; clearing it would make the next tick visible again.
            break
        }
        return decision
    }

    public mutating func reset(sessionID: String) {
        missingSince.removeValue(forKey: sessionID)
    }

    public mutating func prune(existingSessionIDs: Set<String>) {
        missingSince = missingSince.filter { existingSessionIDs.contains($0.key) }
    }
}
