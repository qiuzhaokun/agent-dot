import Foundation

public enum SessionVisibilityResult: Equatable {
    case visible(nextMissingSince: Int64?)
    case hidden
}

public enum SessionVisibility {
    public static func evaluate(
        state: SessionState,
        now: Int64,
        isProcessAlive: Bool,
        missingSince: Int64?,
        graceSeconds: Int64 = 3,
        endedLingerSeconds: Int64 = 3
    ) -> SessionVisibilityResult {
        if state.state == .ended {
            return now - state.updatedAt < endedLingerSeconds
                ? .visible(nextMissingSince: nil)
                : .hidden
        }

        if state.terminal.claudePID == 0 {
            return .visible(nextMissingSince: nil)
        }

        if isProcessAlive {
            return .visible(nextMissingSince: nil)
        }

        if let missingSince {
            if now - missingSince < graceSeconds {
                return .visible(nextMissingSince: missingSince)
            }
            return .hidden
        }

        return .visible(nextMissingSince: now)
    }
}
