import Foundation

public enum SessionReminderEvent: Equatable {
    case authorization(sessionID: String)
    case completion(sessionID: String)
}

/// 根据可见会话的状态变化生成声音提醒事件。
///
/// - 授权：进入等待授权立即提醒；未确认且仍在等待时每 10 秒重复一次。
/// - 完成：会话从非完成状态变为已完成时提醒一次。
///
/// 启动时已经处于等待/完成状态的会话不会立即触发提醒。
public struct SessionReminderScheduler {
    public static let authorizationRepeatInterval: Int64 = 10

    private var previousPhases: [String: SessionPhase] = [:]
    private var previousWaitingSince: [String: Int64] = [:]
    private var nextAuthorizationReminderAt: [String: Int64] = [:]
    private var hasBaseline = false

    public init() {}

    public mutating func update(
        sessions: [SessionState],
        acknowledgedSessionIDs: Set<String>,
        authorizationEnabled: Bool,
        completionEnabled: Bool,
        now: Int64
    ) -> [SessionReminderEvent] {
        var events: [SessionReminderEvent] = []
        var phases: [String: SessionPhase] = [:]
        var waitingSinceByID: [String: Int64] = [:]
        var nextReminders: [String: Int64] = [:]

        for session in sessions {
            let id = session.sessionID
            phases[id] = session.state
            let previous = previousPhases[id]

            if hasBaseline,
               completionEnabled,
               session.state == .done,
               let previous,
               previous != .done {
                events.append(.completion(sessionID: id))
            }

            guard session.state == .waitingPermission else { continue }
            if let waitingSince = session.waitingSince {
                waitingSinceByID[id] = waitingSince
            }

            guard authorizationEnabled,
                  !acknowledgedSessionIDs.contains(id) else {
                continue
            }

            let currentWaitingSince = session.waitingSince
            let previousWaiting = previousWaitingSince[id]
            let enteredWaiting: Bool
            if !hasBaseline {
                enteredWaiting = false
            } else if previous != .waitingPermission {
                enteredWaiting = true
            } else if currentWaitingSince != previousWaiting {
                enteredWaiting = true
            } else {
                enteredWaiting = false
            }

            if enteredWaiting {
                events.append(.authorization(sessionID: id))
                nextReminders[id] = now + Self.authorizationRepeatInterval
            } else if let due = nextAuthorizationReminderAt[id] {
                if now >= due {
                    events.append(.authorization(sessionID: id))
                    nextReminders[id] = now + Self.authorizationRepeatInterval
                } else {
                    nextReminders[id] = due
                }
            } else {
                // 启动时已在等待，或开关刚打开：下个周期再提醒。
                nextReminders[id] = now + Self.authorizationRepeatInterval
            }
        }

        previousPhases = phases
        previousWaitingSince = waitingSinceByID
        nextAuthorizationReminderAt = nextReminders
        hasBaseline = true
        return events
    }
}
