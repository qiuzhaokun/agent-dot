import Foundation
import AgentDotCore

func runAcknowledgmentPolicyTests() {
    func makeSession(
        app: TerminalApp,
        state: SessionPhase = .waitingPermission,
        iterm: String? = nil,
        tty: String? = nil,
        pane: String? = nil,
        surface: String? = nil
    ) -> SessionState {
        var session = TestSupport.makeSession(state: state, waitingSince: 100)
        session.terminal = TerminalContext(
            app: app,
            tty: tty,
            itermSessionID: iterm,
            termSessionID: nil,
            ghosttySurfaceID: surface,
            weztermPane: pane,
            tmuxPane: nil,
            claudePID: 12345,
            claudeExecPath: "/usr/local/bin/claude"
        )
        return session
    }

    runTest("AcknowledgmentPolicy acks matching iTerm2 session") {
        let session = makeSession(
            app: .iTerm2,
            iterm: "w0t0p0:UUID",
            tty: "/dev/ttys003"
        )
        let snapshot = ActiveTerminalSnapshot(
            frontmostBundleID: "com.googlecode.iterm2",
            iTerm2ActiveSessionID: "UUID",
            iTerm2ActiveTTY: "/dev/ttys003",
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: snapshot))
    }

    runTest("AcknowledgmentPolicy does not ack another iTerm2 tab") {
        let session = makeSession(
            app: .iTerm2,
            iterm: "w0t0p0:UUID",
            tty: "/dev/ttys003"
        )
        let snapshot = ActiveTerminalSnapshot(
            frontmostBundleID: "com.googlecode.iterm2",
            iTerm2ActiveSessionID: "OTHER",
            iTerm2ActiveTTY: "/dev/ttys999",
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: snapshot))
    }

    runTest("AcknowledgmentPolicy does not ack when terminal is not frontmost") {
        let session = makeSession(app: .terminal, tty: "/dev/ttys003")
        let snapshot = ActiveTerminalSnapshot(
            frontmostBundleID: "com.apple.Safari",
            iTerm2ActiveSessionID: nil,
            iTerm2ActiveTTY: nil,
            terminalActiveTTY: "/dev/ttys003",
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: snapshot))
    }

    runTest("AcknowledgmentPolicy acks matching Terminal tty") {
        let session = makeSession(app: .terminal, tty: "/dev/ttys003")
        let snapshot = ActiveTerminalSnapshot(
            frontmostBundleID: "com.apple.Terminal",
            iTerm2ActiveSessionID: nil,
            iTerm2ActiveTTY: nil,
            terminalActiveTTY: "/dev/ttys003",
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: snapshot))
    }

    runTest("AcknowledgmentPolicy acks matching Kaku pane only") {
        let session = makeSession(app: .kaku, pane: "3")
        let matching = ActiveTerminalSnapshot(
            frontmostBundleID: "fun.tw93.kaku",
            iTerm2ActiveSessionID: nil,
            iTerm2ActiveTTY: nil,
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: "3"
        )
        expect(AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: matching))

        var other = matching
        other.kakuActivePaneID = "4"
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: other))
    }

    runTest("AcknowledgmentPolicy requires exact Ghostty surface id") {
        let session = makeSession(app: .ghostty, surface: "123456789")
        let matching = ActiveTerminalSnapshot(
            frontmostBundleID: "com.mitchellh.ghostty",
            iTerm2ActiveSessionID: nil,
            iTerm2ActiveTTY: nil,
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: "123456789",
            kakuActivePaneID: nil
        )
        expect(AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: matching))

        var other = matching
        other.ghosttyActiveTerminalID = "987654321"
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: session, snapshot: other))
    }

    runTest("AcknowledgmentPolicy never acks unknown or non-waiting") {
        let unknown = makeSession(app: .unknown)
        let snapshot = ActiveTerminalSnapshot(
            frontmostBundleID: "dev.agentdot.app",
            iTerm2ActiveSessionID: nil,
            iTerm2ActiveTTY: nil,
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: unknown, snapshot: snapshot))

        let running = makeSession(
            app: .iTerm2,
            state: .running,
            iterm: "w0t0p0:UUID",
            tty: "/dev/ttys003"
        )
        let matching = ActiveTerminalSnapshot(
            frontmostBundleID: "com.googlecode.iterm2",
            iTerm2ActiveSessionID: "UUID",
            iTerm2ActiveTTY: "/dev/ttys003",
            terminalActiveTTY: nil,
            ghosttyActiveTerminalID: nil,
            kakuActivePaneID: nil
        )
        expect(!AcknowledgmentPolicy.shouldAcknowledge(session: running, snapshot: matching))
    }
}
