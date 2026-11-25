import Foundation
import AgentDotCore

func runAcknowledgmentStatePolicyTests() {
    runTest("AcknowledgmentStatePolicy survives restart when waitingSince matches") {
        let session = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        let ui = SessionUIState(acknowledgedAt: 150, waitingSinceAtAck: 100)
        expect(
            AcknowledgmentStatePolicy.isAcknowledged(session: session, uiState: ui)
        )
    }

    runTest("AcknowledgmentStatePolicy invalidates ack for a new waiting period") {
        let session = TestSupport.makeSession(state: .waitingPermission, waitingSince: 200)
        let ui = SessionUIState(acknowledgedAt: 150, waitingSinceAtAck: 100)
        expect(
            !AcknowledgmentStatePolicy.isAcknowledged(session: session, uiState: ui)
        )
    }

    runTest("AcknowledgmentStatePolicy requires waiting state and matching timestamp") {
        let running = TestSupport.makeSession(state: .running)
        let ui = SessionUIState(acknowledgedAt: 150, waitingSinceAtAck: 100)
        expect(!AcknowledgmentStatePolicy.isAcknowledged(session: running, uiState: ui))

        let waiting = TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        expect(!AcknowledgmentStatePolicy.isAcknowledged(session: waiting, uiState: nil))
        expect(!AcknowledgmentStatePolicy.isAcknowledged(
            session: waiting,
            uiState: SessionUIState(acknowledgedAt: nil, waitingSinceAtAck: 100)
        ))
    }
}
