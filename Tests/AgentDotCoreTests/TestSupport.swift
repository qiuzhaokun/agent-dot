import Foundation
import AgentDotCore

enum TestSupport {
    static func makeSession(
        state: SessionPhase = .running,
        waitingSince: Int64? = nil,
        updatedAt: Int64 = 100,
        claudePID: Int32 = 12345
    ) -> SessionState {
        SessionState(
            schema: 1,
            sessionID: "abc123",
            cwd: "/Users/example/webroot/agent-dot",
            projectName: "agent-dot",
            state: state,
            currentTool: nil,
            notificationType: nil,
            errorKind: nil,
            startedAt: 100,
            updatedAt: updatedAt,
            lastActivityAt: 100,
            turnStartedAt: 100,
            turnEndedAt: nil,
            waitingSince: waitingSince,
            terminal: TerminalContext(
                app: .iTerm2,
                tty: "/dev/ttys003",
                itermSessionID: "w0t0p0:UUID",
                termSessionID: nil,
                ghosttySurfaceID: nil,
                weztermPane: nil,
                tmuxPane: nil,
                claudePID: claudePID,
                claudeExecPath: "/usr/local/bin/claude"
            )
        )
    }

    static func makePayload(
        _ event: String,
        sessionID: String = "abc123",
        cwd: String? = "/Users/example/webroot/agent-dot",
        source: String? = nil,
        reason: String? = nil,
        toolName: String? = nil,
        toolUseID: String? = nil,
        notificationType: String? = nil,
        errorType: String? = nil
    ) -> HookPayload {
        HookPayload(
            sessionID: sessionID,
            cwd: cwd,
            hookEventName: event,
            source: source,
            reason: reason,
            toolName: toolName,
            toolUseID: toolUseID,
            notificationType: notificationType,
            errorType: errorType
        )
    }

    static func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
