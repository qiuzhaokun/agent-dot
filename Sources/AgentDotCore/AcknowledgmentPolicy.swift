import Foundation

public struct ActiveTerminalSnapshot: Equatable {
    public var frontmostBundleID: String?
    public var iTerm2ActiveSessionID: String?
    public var iTerm2ActiveTTY: String?
    public var terminalActiveTTY: String?
    public var ghosttyActiveTerminalID: String?
    public var kakuActivePaneID: String?

    public init(
        frontmostBundleID: String? = nil,
        iTerm2ActiveSessionID: String? = nil,
        iTerm2ActiveTTY: String? = nil,
        terminalActiveTTY: String? = nil,
        ghosttyActiveTerminalID: String? = nil,
        kakuActivePaneID: String? = nil
    ) {
        self.frontmostBundleID = frontmostBundleID
        self.iTerm2ActiveSessionID = iTerm2ActiveSessionID
        self.iTerm2ActiveTTY = iTerm2ActiveTTY
        self.terminalActiveTTY = terminalActiveTTY
        self.ghosttyActiveTerminalID = ghosttyActiveTerminalID
        self.kakuActivePaneID = kakuActivePaneID
    }
}

public enum AcknowledgmentPolicy {
    public static func shouldAcknowledge(
        session: SessionState,
        snapshot: ActiveTerminalSnapshot
    ) -> Bool {
        guard session.state == .waitingPermission else {
            return false
        }
        guard let bundle = session.terminal.app.bundleIdentifier,
              snapshot.frontmostBundleID == bundle else {
            return false
        }

        switch session.terminal.app {
        case .iTerm2:
            if let uuid = TerminalIDValidator.itermUUID(
                from: session.terminal.itermSessionID ?? ""
            ), let active = snapshot.iTerm2ActiveSessionID,
               uuid == active {
                return true
            }
            if let tty = session.terminal.tty,
               TerminalIDValidator.isValidTTY(tty),
               let active = snapshot.iTerm2ActiveTTY,
               tty == active {
                return true
            }
            return false

        case .terminal:
            guard let tty = session.terminal.tty,
                  TerminalIDValidator.isValidTTY(tty),
                  let active = snapshot.terminalActiveTTY else {
                return false
            }
            return tty == active

        case .kaku:
            guard let pane = session.terminal.weztermPane,
                  TerminalIDValidator.isValidPaneID(pane),
                  let active = snapshot.kakuActivePaneID else {
                return false
            }
            return pane == active

        case .ghostty:
            guard let surface = session.terminal.ghosttySurfaceID,
                  TerminalIDValidator.isValidSurfaceID(surface),
                  let active = snapshot.ghosttyActiveTerminalID else {
                return false
            }
            return surface == active

        case .unknown:
            return false
        }
    }
}
