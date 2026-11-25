import Foundation
import AgentDotCore

protocol ActiveTerminalProbing {
    func snapshot(
        for app: TerminalApp,
        frontmostBundleID: String?
    ) -> ActiveTerminalSnapshot?
}

struct LiveActiveTerminalProbe: ActiveTerminalProbing {
    func snapshot(
        for app: TerminalApp,
        frontmostBundleID: String?
    ) -> ActiveTerminalSnapshot? {
        guard let bundle = app.bundleIdentifier,
              frontmostBundleID == bundle else {
            return ActiveTerminalSnapshot(frontmostBundleID: frontmostBundleID)
        }

        switch app {
        case .iTerm2:
            return iTerm2Snapshot(frontmost: frontmostBundleID)
        case .terminal:
            return terminalSnapshot(frontmost: frontmostBundleID)
        case .ghostty:
            return ghosttySnapshot(frontmost: frontmostBundleID)
        case .kaku:
            return kakuSnapshot(frontmost: frontmostBundleID)
        case .unknown:
            return nil
        }
    }

    private func iTerm2Snapshot(frontmost: String?) -> ActiveTerminalSnapshot {
        let script = """
        tell application id "com.googlecode.iterm2"
          set s to current session of current window
          return (id of s as text) & "|" & (tty of s as text)
        end tell
        """
        guard case .success(let output) = AppleScriptRunner.run(script) else {
            return ActiveTerminalSnapshot(frontmostBundleID: frontmost)
        }
        let parts = output.split(
            separator: "|",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let sessionID = parts.first.map(String.init) ?? ""
        let tty = parts.count > 1 ? String(parts[1]) : ""
        return ActiveTerminalSnapshot(
            frontmostBundleID: frontmost,
            iTerm2ActiveSessionID: sessionID.isEmpty ? nil : sessionID,
            iTerm2ActiveTTY: tty.isEmpty ? nil : tty
        )
    }

    private func terminalSnapshot(frontmost: String?) -> ActiveTerminalSnapshot {
        let script = """
        tell application id "com.apple.Terminal"
          return tty of selected tab of front window as text
        end tell
        """
        guard case .success(let output) = AppleScriptRunner.run(script) else {
            return ActiveTerminalSnapshot(frontmostBundleID: frontmost)
        }
        return ActiveTerminalSnapshot(
            frontmostBundleID: frontmost,
            terminalActiveTTY: output.isEmpty ? nil : output
        )
    }

    private func ghosttySnapshot(frontmost: String?) -> ActiveTerminalSnapshot {
        let script = """
        tell application id "com.mitchellh.ghostty"
          return id of focused terminal of selected tab of front window as text
        end tell
        """
        guard case .success(let output) = AppleScriptRunner.run(script) else {
            return ActiveTerminalSnapshot(frontmostBundleID: frontmost)
        }
        return ActiveTerminalSnapshot(
            frontmostBundleID: frontmost,
            ghosttyActiveTerminalID: output.isEmpty ? nil : output
        )
    }

    private func kakuSnapshot(frontmost: String?) -> ActiveTerminalSnapshot {
        guard let result = KakuCLI.run(
            ["cli", "list", "--format", "json"],
            timeout: 1.0
        ), result.status == 0,
           let data = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let pane = KakuActivePaneParser.activePaneID(from: json) else {
            return ActiveTerminalSnapshot(frontmostBundleID: frontmost)
        }
        return ActiveTerminalSnapshot(
            frontmostBundleID: frontmost,
            kakuActivePaneID: pane
        )
    }
}
