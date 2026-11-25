import Foundation
import AgentDotCore

func runSessionVisibilityTrackerTests() {
    runTest("SessionVisibilityTracker keeps dead sessions hidden across cycles") {
        var tracker = SessionVisibilityTracker()
        let state = TestSupport.makeSession(state: .done, updatedAt: 100)
        expectEqual(
            tracker.evaluate(state: state, now: 200, isProcessAlive: false),
            .visible(nextMissingSince: 200)
        )
        expectEqual(
            tracker.evaluate(state: state, now: 204, isProcessAlive: false),
            .hidden
        )
        expectEqual(
            tracker.evaluate(state: state, now: 205, isProcessAlive: false),
            .hidden
        )
        expectEqual(
            tracker.evaluate(state: state, now: 206, isProcessAlive: false),
            .hidden
        )
    }

    runTest("SessionVisibilityTracker alive resets hidden state") {
        var tracker = SessionVisibilityTracker()
        let state = TestSupport.makeSession(state: .running, updatedAt: 100)
        _ = tracker.evaluate(state: state, now: 200, isProcessAlive: false)
        expectEqual(
            tracker.evaluate(state: state, now: 204, isProcessAlive: false),
            .hidden
        )
        expectEqual(
            tracker.evaluate(state: state, now: 205, isProcessAlive: true),
            .visible(nextMissingSince: nil)
        )
        expectEqual(
            tracker.evaluate(state: state, now: 210, isProcessAlive: false),
            .visible(nextMissingSince: 210)
        )
    }

    runTest("SessionVisibilityTracker reset starts a new grace period") {
        var tracker = SessionVisibilityTracker()
        let state = TestSupport.makeSession(state: .running, updatedAt: 100)
        _ = tracker.evaluate(state: state, now: 200, isProcessAlive: false)
        expectEqual(
            tracker.evaluate(state: state, now: 204, isProcessAlive: false),
            .hidden
        )
        tracker.reset(sessionID: state.sessionID)
        expectEqual(
            tracker.evaluate(state: state, now: 205, isProcessAlive: false),
            .visible(nextMissingSince: 205)
        )
    }

    runTest("SessionVisibilityTracker prune drops missing session state") {
        var tracker = SessionVisibilityTracker()
        let state = TestSupport.makeSession(state: .running, updatedAt: 100)
        _ = tracker.evaluate(state: state, now: 200, isProcessAlive: false)
        tracker.prune(existingSessionIDs: [])
        expectEqual(
            tracker.evaluate(state: state, now: 205, isProcessAlive: false),
            .visible(nextMissingSince: 205)
        )
    }
}
