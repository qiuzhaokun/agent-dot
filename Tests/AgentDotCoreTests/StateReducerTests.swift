import Foundation
import AgentDotCore

func runStateReducerTests() {
    runTest("StateReducer PreToolUse does not clear waiting") {
        let existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let payload = TestSupport.makePayload("PreToolUse", toolName: "Bash")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.waitingSince, 100)
        expectEqual(out.currentTool, "Bash")
        expectEqual(out.updatedAt, 200)
    }

    runTest("StateReducer PostToolUse clears waiting") {
        let existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let payload = TestSupport.makePayload("PostToolUse", toolName: "Bash")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .running)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
    }

    runTest("StateReducer PermissionRequest sets waiting") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("PermissionRequest", toolName: "Bash")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.waitingSince, 200)
        expectEqual(out.currentTool, "Bash")
    }

    runTest("StateReducer duplicate PermissionRequest preserves waitingSince") {
        let existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let payload = TestSupport.makePayload("PermissionRequest", toolName: "Bash")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.waitingSince, 100)
    }

    runTest("StateReducer PermissionDenied clears waiting") {
        let existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let payload = TestSupport.makePayload("PermissionDenied", toolName: "Bash")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .running)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
    }

    runTest("StateReducer resume from running becomes idle") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("SessionStart", source: "resume")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .idle)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
        expectNil(out.turnStartedAt)
    }

    runTest("StateReducer compact keeps running") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("SessionStart", source: "compact")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .running)
    }

    runTest("StateReducer clear resets to idle") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("SessionStart", source: "clear")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .idle)
        expectNil(out.currentTool)
        expectNil(out.waitingSince)
        expectNil(out.turnStartedAt)
        expectNil(out.turnEndedAt)
    }

    runTest("StateReducer startup creates idle from nil") {
        let payload = TestSupport.makePayload("SessionStart", source: "startup")
        let terminal = TestSupport.makeSession().terminal
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: nil, terminal: terminal, now: 200
        ))
        expectEqual(out.state, .idle)
        expectEqual(out.sessionID, "abc123")
        expectEqual(out.projectName, "agent-dot")
        expectEqual(out.startedAt, 200)
        expectEqual(out.updatedAt, 200)
        expectEqual(out.terminal.app, .iTerm2)
    }

    runTest("StateReducer UserPromptSubmit sets running and turn start") {
        let existing = TestSupport.makeSession(state: .done)
        let payload = TestSupport.makePayload("UserPromptSubmit")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .running)
        expectEqual(out.turnStartedAt, 200)
        expectNil(out.turnEndedAt)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
    }

    runTest("StateReducer Notification permission_prompt sets waiting") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("Notification", notificationType: "permission_prompt")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.waitingSince, 200)
        expectEqual(out.notificationType, "permission_prompt")
    }

    runTest("StateReducer Notification idle_prompt sets done") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("Notification", notificationType: "idle_prompt")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .done)
        expectEqual(out.turnEndedAt, 200)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
    }

    runTest("StateReducer idle_prompt does not clear waiting") {
        let existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let payload = TestSupport.makePayload("Notification", notificationType: "idle_prompt")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.waitingSince, 100)
    }

    runTest("StateReducer AskUserQuestion enters waiting for input") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("PreToolUse", toolName: "AskUserQuestion")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.notificationType, SessionAttention.userQuestion)
        expectEqual(out.waitingSince, 200)
        expectEqual(out.currentTool, "AskUserQuestion")
    }

    runTest("StateReducer ExitPlanMode enters waiting for approval") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("PreToolUse", toolName: "ExitPlanMode")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .waitingPermission)
        expectEqual(out.notificationType, SessionAttention.planApproval)
        expectEqual(out.waitingSince, 200)
    }

    runTest("StateReducer Notification auth_success clears waiting") {
        var existing = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        existing.notificationType = SessionAttention.elicitationDialog
        let payload = TestSupport.makePayload("Notification", notificationType: "auth_success")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
        expectEqual(out.state, .running)
        expectNil(out.waitingSince)
        expectNil(out.notificationType)
    }

    runTest("StateReducer Notification elicitation types set waiting") {
        for type in [
            SessionAttention.elicitationDialog,
            SessionAttention.elicitationURLDialog,
            SessionAttention.workerPermissionPrompt
        ] {
            let existing = TestSupport.makeSession(state: .running)
            let payload = TestSupport.makePayload("Notification", notificationType: type)
            let out = try unwrap(StateReducer().apply(
                payload: payload, existing: existing, terminal: existing.terminal, now: 200
            ))
            expectEqual(out.state, .waitingPermission)
            expectEqual(out.notificationType, type)
            expectEqual(out.waitingSince, 200)
        }
    }

    runTest("StateReducer Notification other type is ignored") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("Notification", notificationType: "auth_success")
        expectNil(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 200
        ))
    }

    runTest("StateReducer Stop sets done and turn end") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("Stop")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 300
        ))
        expectEqual(out.state, .done)
        expectEqual(out.turnEndedAt, 300)
        expectNil(out.waitingSince)
        expectNil(out.currentTool)
    }

    runTest("StateReducer StopFailure sets error") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("StopFailure", errorType: "rate_limit")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 300
        ))
        expectEqual(out.state, .error)
        expectEqual(out.errorKind, "rate_limit")
        expectEqual(out.turnEndedAt, 300)
    }

    runTest("StateReducer SessionEnd marks ended") {
        let existing = TestSupport.makeSession(state: .running)
        let payload = TestSupport.makePayload("SessionEnd", reason: "other")
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: existing, terminal: existing.terminal, now: 300
        ))
        expectEqual(out.state, .ended)
        expectEqual(out.turnEndedAt, 300)
        expectNil(out.waitingSince)
    }

    runTest("StateReducer PreToolUse without existing creates running") {
        let payload = TestSupport.makePayload("PreToolUse", toolName: "Bash")
        let terminal = TestSupport.makeSession().terminal
        let out = try unwrap(StateReducer().apply(
            payload: payload, existing: nil, terminal: terminal, now: 200
        ))
        expectEqual(out.state, .running)
        expectEqual(out.currentTool, "Bash")
        expectEqual(out.startedAt, 200)
    }

    runTest("StateReducer bounds cwd and tool name") {
        let longCwd = String(repeating: "a", count: 2000)
        let longTool = String(repeating: "b", count: 100)
        let payload = TestSupport.makePayload(
            "PreToolUse",
            cwd: longCwd,
            toolName: longTool
        )
        let terminal = TestSupport.makeSession().terminal
        let out = try unwrap(StateReducer().apply(
            payload: payload,
            existing: nil,
            terminal: terminal,
            now: 200
        ))
        expectEqual(out.cwd.count, 1024)
        expectEqual(out.currentTool?.count, 64)
    }

    runTest("StateReducer unknown event returns nil") {
        let payload = TestSupport.makePayload("SomethingNew")
        expectNil(StateReducer().apply(
            payload: payload,
            existing: TestSupport.makeSession(),
            terminal: TestSupport.makeSession().terminal,
            now: 200
        ))
    }
}
