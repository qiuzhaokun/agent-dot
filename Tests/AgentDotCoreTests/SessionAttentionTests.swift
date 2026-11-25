import Foundation
import AgentDotCore

private func attentionSession(
    state: SessionPhase,
    tool: String? = nil,
    lastActivityAt: Int64 = 100
) -> SessionState {
    var session = TestSupport.makeSession(state: state)
    session.currentTool = tool
    session.lastActivityAt = lastActivityAt
    session.updatedAt = lastActivityAt
    return session
}

func runSessionAttentionTests() {
    runTest("SessionAttention external wait after twenty seconds") {
        let running = attentionSession(
            state: .running,
            tool: "mcp__idea__execute_sql_query",
            lastActivityAt: 100
        )
        let before = running.applyingExternalWaitAttention(now: 119)
        expectEqual(before.state, .running)
        expectNil(before.notificationType)

        let after = running.applyingExternalWaitAttention(now: 120)
        expectEqual(after.state, .waitingPermission)
        expectEqual(after.notificationType, SessionAttention.externalWait)
        expectEqual(after.waitingSince, 100)
    }

    runTest("SessionAttention external wait requires a running tool") {
        let noTool = attentionSession(state: .running, lastActivityAt: 100)
        expectEqual(
            noTool.applyingExternalWaitAttention(now: 200).state,
            .running
        )

        let alreadyWaiting = attentionSession(
            state: .waitingPermission,
            tool: "Bash",
            lastActivityAt: 100
        )
        expectEqual(
            alreadyWaiting.applyingExternalWaitAttention(now: 200).state,
            .waitingPermission
        )

        let missingActivity = attentionSession(
            state: .running,
            tool: "Bash",
            lastActivityAt: 0
        )
        expectEqual(
            missingActivity.applyingExternalWaitAttention(now: 200).state,
            .running
        )
    }

    runTest("SessionAttention plain question turns done into waiting") {
        let done = attentionSession(state: .done)
        let waiting = done.applyingPlainQuestionAttention(now: 200, isQuestion: true)
        expectEqual(waiting.state, .waitingPermission)
        expectEqual(waiting.notificationType, SessionAttention.plainQuestion)
        expectEqual(waiting.waitingSince, 200)
        expectEqual(waiting.turnEndedAt, 200)
        expectNil(waiting.currentTool)

        expectEqual(
            done.applyingPlainQuestionAttention(now: 200, isQuestion: false).state,
            .done
        )
        let running = attentionSession(state: .running)
        expectEqual(
            running.applyingPlainQuestionAttention(now: 200, isQuestion: true).state,
            .running
        )
    }

    runTest("SessionAttention manual acknowledgment only for external and plain states") {
        expect(SessionAttention.requiresManualAcknowledgment(SessionAttention.externalWait))
        expect(SessionAttention.requiresManualAcknowledgment(SessionAttention.plainQuestion))
        expect(!SessionAttention.requiresManualAcknowledgment(SessionAttention.userQuestion))
        expect(!SessionAttention.requiresManualAcknowledgment(SessionAttention.planApproval))
        expect(!SessionAttention.requiresManualAcknowledgment("permission_request"))
        expect(!SessionAttention.requiresManualAcknowledgment(nil))
    }
}
