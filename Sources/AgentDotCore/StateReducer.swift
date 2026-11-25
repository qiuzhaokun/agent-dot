import Foundation

public struct StateReducer {
    public init() {}

    public func apply(
        payload: HookPayload,
        existing: SessionState?,
        terminal: TerminalContext,
        now: Int64
    ) -> SessionState? {
        guard let event = Event(rawValue: payload.hookEventName) else {
            return nil
        }

        var state = existing ?? baseline(payload: payload, terminal: terminal, now: now)
        state.terminal = terminal
        state.updatedAt = now

        switch event {
        case .sessionStart:
            state = reduceSessionStart(state, payload: payload, now: now)
        case .userPromptSubmit:
            state.state = .running
            state.currentTool = nil
            state.notificationType = nil
            state.errorKind = nil
            state.waitingSince = nil
            state.turnStartedAt = now
            state.turnEndedAt = nil
            state.lastActivityAt = now
        case .preToolUse:
            if state.state != .waitingPermission {
                state.state = .running
                state.notificationType = nil
            }
            state.currentTool = payload.toolName.map { limited($0, max: 64) }
            state.lastActivityAt = now
        case .postToolUse:
            state.state = .running
            state.currentTool = nil
            state.notificationType = nil
            state.waitingSince = nil
            state.lastActivityAt = now
        case .permissionRequest:
            state.state = .waitingPermission
            if state.waitingSince == nil {
                state.waitingSince = now
            }
            if state.turnStartedAt == nil {
                state.turnStartedAt = now
            }
            state.turnEndedAt = nil
            state.currentTool = payload.toolName.map { limited($0, max: 64) }
            state.notificationType = "permission_request"
            state.lastActivityAt = now
        case .permissionDenied:
            state.state = .running
            state.waitingSince = nil
            state.currentTool = nil
            state.notificationType = nil
            state.lastActivityAt = now
        case .notification:
            switch payload.notificationType {
            case "permission_prompt", "agent_needs_input":
                state.state = .waitingPermission
                if state.waitingSince == nil {
                    state.waitingSince = now
                }
                if state.turnStartedAt == nil {
                    state.turnStartedAt = now
                }
                state.notificationType = payload.notificationType
                state.lastActivityAt = now
            case "idle_prompt":
                state.state = .done
                state.turnEndedAt = now
                state.waitingSince = nil
                state.currentTool = nil
                state.notificationType = payload.notificationType
                state.lastActivityAt = now
            default:
                return nil
            }
        case .stop:
            state.state = .done
            state.turnEndedAt = now
            state.waitingSince = nil
            state.currentTool = nil
            state.notificationType = nil
            state.lastActivityAt = now
        case .stopFailure:
            state.state = .error
            state.turnEndedAt = now
            state.waitingSince = nil
            state.currentTool = nil
            state.notificationType = nil
            if let errorType = payload.errorType {
                state.errorKind = errorType
            }
            state.lastActivityAt = now
        case .sessionEnd:
            let wasActive = state.state == .running || state.state == .waitingPermission
            state.state = .ended
            state.waitingSince = nil
            state.currentTool = nil
            state.notificationType = nil
            if wasActive {
                state.turnEndedAt = now
            }
            state.lastActivityAt = now
        }

        state.updatedAt = now
        return state
    }

    private func baseline(
        payload: HookPayload,
        terminal: TerminalContext,
        now: Int64
    ) -> SessionState {
        let cwd = limited(payload.cwd ?? "", max: 1024)
        return SessionState(
            schema: 1,
            sessionID: payload.sessionID,
            cwd: cwd,
            projectName: SessionState.projectName(forCWD: cwd),
            state: .idle,
            startedAt: now,
            updatedAt: now,
            lastActivityAt: now,
            terminal: terminal
        )
    }

    private func reduceSessionStart(
        _ state: SessionState,
        payload: HookPayload,
        now: Int64
    ) -> SessionState {
        var state = state
        switch payload.source ?? "startup" {
        case "compact":
            state.lastActivityAt = now
        case "resume":
            if state.state == .done {
                state.lastActivityAt = now
            } else {
                resetToIdle(&state, now: now)
            }
        case "clear":
            resetToIdle(&state, now: now)
        default:
            resetToIdle(&state, now: now)
        }
        return state
    }

    private func limited(_ value: String, max: Int) -> String {
        value.count <= max ? value : String(value.prefix(max))
    }

    private func resetToIdle(_ state: inout SessionState, now: Int64) {
        state.state = .idle
        state.currentTool = nil
        state.notificationType = nil
        state.errorKind = nil
        state.waitingSince = nil
        state.turnStartedAt = nil
        state.turnEndedAt = nil
        state.lastActivityAt = now
    }

    private enum Event: String {
        case sessionStart = "SessionStart"
        case userPromptSubmit = "UserPromptSubmit"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
        case permissionRequest = "PermissionRequest"
        case permissionDenied = "PermissionDenied"
        case notification = "Notification"
        case stop = "Stop"
        case stopFailure = "StopFailure"
        case sessionEnd = "SessionEnd"
    }
}
