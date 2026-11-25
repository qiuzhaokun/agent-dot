import Foundation

public enum AcknowledgmentStatePolicy {
    public static func isAcknowledged(
        session: SessionState,
        uiState: SessionUIState?
    ) -> Bool {
        guard session.state == .waitingPermission,
              let uiState,
              uiState.acknowledgedAt != nil,
              let waitingSince = session.waitingSince,
              let recorded = uiState.waitingSinceAtAck else {
            return false
        }
        return recorded == waitingSince
    }
}
