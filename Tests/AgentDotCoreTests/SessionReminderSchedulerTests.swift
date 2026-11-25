import Foundation
import AgentDotCore

private func reminderSession(
    id: String,
    state: SessionPhase,
    waitingSince: Int64? = nil
) -> SessionState {
    var session = TestSupport.makeSession(state: state, waitingSince: waitingSince)
    session.sessionID = id
    return session
}

private func updateScheduler(
    _ scheduler: inout SessionReminderScheduler,
    sessions: [SessionState],
    acknowledged: Set<String> = [],
    authorizationEnabled: Bool = true,
    completionEnabled: Bool = true,
    now: Int64
) -> [SessionReminderEvent] {
    scheduler.update(
        sessions: sessions,
        acknowledgedSessionIDs: acknowledged,
        authorizationEnabled: authorizationEnabled,
        completionEnabled: completionEnabled,
        now: now
    )
}

func runSessionReminderSchedulerTests() {
    runTest("SessionReminderScheduler baseline waiting reminds after ten seconds") {
        var scheduler = SessionReminderScheduler()
        let waiting = reminderSession(
            id: "a",
            state: .waitingPermission,
            waitingSince: 100
        )

        expect(
            updateScheduler(&scheduler, sessions: [waiting], now: 100).isEmpty
        )
        expect(
            updateScheduler(&scheduler, sessions: [waiting], now: 109).isEmpty
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waiting], now: 110),
            [.authorization(sessionID: "a")]
        )
        expect(
            updateScheduler(&scheduler, sessions: [waiting], now: 119).isEmpty
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waiting], now: 120),
            [.authorization(sessionID: "a")]
        )
    }

    runTest("SessionReminderScheduler entering waiting reminds immediately") {
        var scheduler = SessionReminderScheduler()
        let running = reminderSession(id: "b", state: .running)
        _ = updateScheduler(&scheduler, sessions: [running], now: 100)

        let waiting = reminderSession(
            id: "b",
            state: .waitingPermission,
            waitingSince: 101
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waiting], now: 101),
            [.authorization(sessionID: "b")]
        )
        expect(
            updateScheduler(&scheduler, sessions: [waiting], now: 110).isEmpty
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waiting], now: 111),
            [.authorization(sessionID: "b")]
        )
    }

    runTest("SessionReminderScheduler stops reminders when acknowledged") {
        var scheduler = SessionReminderScheduler()
        let running = reminderSession(id: "c", state: .running)
        _ = updateScheduler(&scheduler, sessions: [running], now: 100)

        let waiting = reminderSession(
            id: "c",
            state: .waitingPermission,
            waitingSince: 101
        )
        _ = updateScheduler(&scheduler, sessions: [waiting], now: 101)

        expect(
            updateScheduler(
                &scheduler,
                sessions: [waiting],
                acknowledged: ["c"],
                now: 102
            ).isEmpty
        )
        expect(
            updateScheduler(
                &scheduler,
                sessions: [waiting],
                acknowledged: ["c"],
                now: 120
            ).isEmpty
        )
        expect(
            updateScheduler(&scheduler, sessions: [waiting], now: 121).isEmpty
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waiting], now: 131),
            [.authorization(sessionID: "c")]
        )
    }

    runTest("SessionReminderScheduler new waiting period reminds immediately") {
        var scheduler = SessionReminderScheduler()
        let waiting = reminderSession(
            id: "d",
            state: .waitingPermission,
            waitingSince: 100
        )
        _ = updateScheduler(&scheduler, sessions: [waiting], now: 100)

        let renewed = reminderSession(
            id: "d",
            state: .waitingPermission,
            waitingSince: 101
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [renewed], now: 101),
            [.authorization(sessionID: "d")]
        )
    }

    runTest("SessionReminderScheduler completion fires once per turn") {
        var scheduler = SessionReminderScheduler()
        let running = reminderSession(id: "e", state: .running)
        _ = updateScheduler(&scheduler, sessions: [running], now: 100)

        let done = reminderSession(id: "e", state: .done)
        expectEqual(
            updateScheduler(&scheduler, sessions: [done], now: 101),
            [.completion(sessionID: "e")]
        )
        expect(
            updateScheduler(&scheduler, sessions: [done], now: 102).isEmpty
        )

        expect(
            updateScheduler(&scheduler, sessions: [running], now: 103).isEmpty
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [done], now: 104),
            [.completion(sessionID: "e")]
        )
    }

    runTest("SessionReminderScheduler baseline done does not remind") {
        var scheduler = SessionReminderScheduler()
        let done = reminderSession(id: "f", state: .done)
        expect(
            updateScheduler(&scheduler, sessions: [done], now: 100).isEmpty
        )
        expect(
            updateScheduler(&scheduler, sessions: [done], now: 110).isEmpty
        )
    }

    runTest("SessionReminderScheduler disabled sounds stay silent") {
        var scheduler = SessionReminderScheduler()
        let running = reminderSession(id: "g", state: .running)
        let done = reminderSession(id: "g", state: .done)
        _ = updateScheduler(
            &scheduler,
            sessions: [running],
            completionEnabled: false,
            now: 100
        )
        expect(
            updateScheduler(
                &scheduler,
                sessions: [done],
                completionEnabled: false,
                now: 101
            ).isEmpty
        )
        expect(
            updateScheduler(
                &scheduler,
                sessions: [done],
                completionEnabled: true,
                now: 102
            ).isEmpty
        )

        var waitingScheduler = SessionReminderScheduler()
        let waiting = reminderSession(
            id: "h",
            state: .waitingPermission,
            waitingSince: 200
        )
        expect(
            updateScheduler(
                &waitingScheduler,
                sessions: [waiting],
                authorizationEnabled: false,
                now: 200
            ).isEmpty
        )
        expect(
            updateScheduler(
                &waitingScheduler,
                sessions: [waiting],
                authorizationEnabled: true,
                now: 205
            ).isEmpty
        )
        expectEqual(
            updateScheduler(
                &waitingScheduler,
                sessions: [waiting],
                authorizationEnabled: true,
                now: 215
            ),
            [.authorization(sessionID: "h")]
        )
    }

    runTest("SessionReminderScheduler external wait reminds once") {
        var scheduler = SessionReminderScheduler()
        var running = reminderSession(id: "j", state: .running)
        running.currentTool = "mcp__idea__execute_sql_query"
        running.lastActivityAt = 100
        running.updatedAt = 100
        _ = updateScheduler(&scheduler, sessions: [running], now: 100)

        let external = running.applyingExternalWaitAttention(now: 120)
        expectEqual(external.state, .waitingPermission)
        expectEqual(
            updateScheduler(&scheduler, sessions: [external], now: 120),
            [.authorization(sessionID: "j")]
        )
        expect(
            updateScheduler(&scheduler, sessions: [external], now: 130).isEmpty
        )
        expect(
            updateScheduler(&scheduler, sessions: [external], now: 140).isEmpty
        )
    }

    runTest("SessionReminderScheduler leaving waiting clears schedule") {
        var scheduler = SessionReminderScheduler()
        let running = reminderSession(id: "i", state: .running)
        _ = updateScheduler(&scheduler, sessions: [running], now: 100)

        let waiting = reminderSession(
            id: "i",
            state: .waitingPermission,
            waitingSince: 101
        )
        _ = updateScheduler(&scheduler, sessions: [waiting], now: 101)

        expect(
            updateScheduler(&scheduler, sessions: [running], now: 105).isEmpty
        )
        let waitingAgain = reminderSession(
            id: "i",
            state: .waitingPermission,
            waitingSince: 106
        )
        expectEqual(
            updateScheduler(&scheduler, sessions: [waitingAgain], now: 106),
            [.authorization(sessionID: "i")]
        )
    }
}
