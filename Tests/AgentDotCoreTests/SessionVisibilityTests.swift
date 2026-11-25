import Foundation
import AgentDotCore

func runSessionVisibilityTests() {
    runTest("SessionVisibility done with dead process hides after grace") {
        let state = TestSupport.makeSession(state: .done, updatedAt: 100)
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 200,
                isProcessAlive: false,
                missingSince: nil
            ),
            .visible(nextMissingSince: 200)
        )
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 204,
                isProcessAlive: false,
                missingSince: 200
            ),
            .hidden
        )
    }

    runTest("SessionVisibility alive resets missingSince") {
        let state = TestSupport.makeSession(state: .done)
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 200,
                isProcessAlive: true,
                missingSince: 100
            ),
            .visible(nextMissingSince: nil)
        )
    }

    runTest("SessionVisibility ended lingers exactly three seconds") {
        let state = TestSupport.makeSession(state: .ended, updatedAt: 100)
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 102,
                isProcessAlive: false,
                missingSince: nil
            ),
            .visible(nextMissingSince: nil)
        )
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 104,
                isProcessAlive: false,
                missingSince: nil
            ),
            .hidden
        )
    }

    runTest("SessionVisibility pid zero is treated as alive") {
        let state = TestSupport.makeSession(state: .done, claudePID: 0)
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 200,
                isProcessAlive: false,
                missingSince: 100
            ),
            .visible(nextMissingSince: nil)
        )
    }

    runTest("SessionVisibility running dead process hides after grace") {
        let state = TestSupport.makeSession(state: .running, updatedAt: 100)
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 200,
                isProcessAlive: false,
                missingSince: nil
            ),
            .visible(nextMissingSince: 200)
        )
        expectEqual(
            SessionVisibility.evaluate(
                state: state,
                now: 203,
                isProcessAlive: false,
                missingSince: 200
            ),
            .hidden
        )
    }
}
