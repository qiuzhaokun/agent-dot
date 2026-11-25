import Foundation
import AgentDotCore

func runSessionStateTests() {
    runTest("SessionState decodes spec sample JSON") {
        let json = """
        {"schema":1,"session_id":"abc123","cwd":"/Users/example/webroot/xbo/datagrip","project_name":"datagrip","state":"waiting_permission","current_tool":"Bash","notification_type":"permission_prompt","error_kind":null,"started_at":1764079200,"updated_at":1764079260,"last_activity_at":1764079260,"turn_started_at":1764079200,"turn_ended_at":null,"waiting_since":1764079260,"terminal":{"app":"iTerm2","tty":"/dev/ttys003","iterm_session_id":"w0t0p0:UUID","term_session_id":null,"ghostty_surface_id":null,"wezterm_pane":null,"tmux_pane":null,"claude_pid":12345,"claude_exec_path":"/usr/local/bin/claude"}}
        """.data(using: .utf8)!
        let state = try JSONDecoder().decode(SessionState.self, from: json)
        expectEqual(state.sessionID, "abc123")
        expectEqual(state.projectName, "datagrip")
        expectEqual(state.state, .waitingPermission)
        expectEqual(state.currentTool, "Bash")
        expectEqual(state.waitingSince, 1764079260)
        expectEqual(state.terminal.app, .iTerm2)
        expectNil(state.terminal.ghosttySurfaceID)
        expectEqual(state.terminal.claudeExecPath, "/usr/local/bin/claude")
    }

    runTest("SessionState encodes snake_case keys") {
        let data = try JSONEncoder().encode(
            TestSupport.makeSession(state: .waitingPermission, waitingSince: 100)
        )
        let obj = try unwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        expectNotNil(obj["session_id"])
        expectNotNil(obj["waiting_since"])
        expectNotNil(obj["turn_started_at"])
        let terminal = try unwrap(obj["terminal"] as? [String: Any])
        expectNotNil(terminal["iterm_session_id"])
        expectNil(obj["muted_at"])
    }

    runTest("SessionState projectName uses last path component") {
        expectEqual(
            SessionState.projectName(forCWD: "/Users/example/webroot/agent-dot", homeDirectory: "/Users/example"),
            "agent-dot"
        )
        expectEqual(
            SessionState.projectName(forCWD: "/Users/example", homeDirectory: "/Users/example"),
            "~"
        )
        expectEqual(
            SessionState.projectName(forCWD: "", homeDirectory: "/Users/example"),
            "unknown"
        )
    }

    runTest("AgentDotPaths honors AGENTDOT_STATE_DIR") {
        let url = AgentDotPaths.stateDirectory(
            environment: ["AGENTDOT_STATE_DIR": "/tmp/agentdot-test"],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )
        expectEqual(url.path, "/tmp/agentdot-test")
    }
}
