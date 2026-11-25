import Foundation
import AppKit
import AgentDotCore

enum JumpResult: Equatable {
    case success
    case unsupported(String)
    case failed(String)
}

struct TerminalJumper {
    func jump(to session: SessionState) -> JumpResult {
        switch session.terminal.app {
        case .iTerm2:
            return jumpITerm2(session)
        case .terminal:
            return jumpTerminal(session)
        case .kaku:
            return jumpKaku(session)
        case .ghostty:
            return jumpGhostty(session)
        case .unknown:
            return .unsupported("未检测到可跳转的终端")
        }
    }

    private func jumpITerm2(_ session: SessionState) -> JumpResult {
        let uuid = TerminalIDValidator.itermUUID(
            from: session.terminal.itermSessionID ?? ""
        )
        let tty = session.terminal.tty.flatMap {
            TerminalIDValidator.isValidTTY($0) ? $0 : nil
        }

        var conditions: [String] = []
        if let uuid {
            conditions.append(
                "(id of s as text) is \"\(TerminalIDValidator.escapeAppleScript(uuid))\""
            )
        }
        if let tty {
            conditions.append(
                "(tty of s as text) is \"\(TerminalIDValidator.escapeAppleScript(tty))\""
            )
        }
        guard !conditions.isEmpty else {
            return .failed("iTerm2 会话标识缺失")
        }

        let script = """
        tell application id "com.googlecode.iterm2"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if \(conditions.joined(separator: " or ")) then
                  select s
                  activate
                  return "ok"
                end if
              end repeat
            end repeat
          end repeat
        end tell
        """
        return run(script, failure: "未找到 iTerm2 会话")
    }

    private func jumpTerminal(_ session: SessionState) -> JumpResult {
        guard let tty = session.terminal.tty,
              TerminalIDValidator.isValidTTY(tty) else {
            return .failed("Terminal 会话 tty 缺失")
        }
        let script = """
        tell application id "com.apple.Terminal"
          repeat with w in windows
            repeat with t in tabs of w
              if (tty of t as text) is "\(TerminalIDValidator.escapeAppleScript(tty))" then
                set selected tab of w to t
                set index of w to 1
                activate
                return "ok"
              end if
            end repeat
          end repeat
        end tell
        """
        return run(script, failure: "未找到 Terminal 标签页")
    }

    private func jumpKaku(_ session: SessionState) -> JumpResult {
        guard let pane = session.terminal.weztermPane,
              TerminalIDValidator.isValidPaneID(pane) else {
            return .failed("Kaku pane id 缺失")
        }
        guard let result = KakuCLI.run(
            ["cli", "activate-pane", "--pane-id", pane]
        ) else {
            activateApp("fun.tw93.kaku")
            return .failed("找不到 kaku CLI 或执行超时，已激活 Kaku")
        }
        guard result.status == 0 else {
            activateApp("fun.tw93.kaku")
            return .failed("kaku activate-pane 失败（exit \(result.status)），已激活 Kaku")
        }

        activateApp("fun.tw93.kaku")
        return .success
    }

    private func jumpGhostty(_ session: SessionState) -> JumpResult {
        var parts: [String] = []

        if let surface = session.terminal.ghosttySurfaceID,
           TerminalIDValidator.isValidSurfaceID(surface) {
            parts.append("""
              set hits to every terminal whose id is "\(surface)"
              if (count of hits) > 0 then
                focus (item 1 of hits)
                activate
                return "ok"
              end if
            """)
        }

        let cwd = session.cwd
        if !cwd.isEmpty,
           cwd.rangeOfCharacter(from: .controlCharacters) == nil {
            parts.append("""
              set hits to every terminal whose working directory is "\(TerminalIDValidator.escapeAppleScript(cwd))"
              if (count of hits) > 0 then
                focus (item 1 of hits)
                activate
                return "ok"
              end if
            """)
        }

        guard !parts.isEmpty else {
            activateApp("com.mitchellh.ghostty")
            return .failed("Ghostty 会话标识缺失，已激活 Ghostty")
        }

        let script = """
        tell application id "com.mitchellh.ghostty"
        \(parts.joined(separator: "\n"))
        end tell
        """

        switch AppleScriptRunner.run(script) {
        case .success(let output) where output == "ok":
            return .success
        case .success:
            activateApp("com.mitchellh.ghostty")
            return .failed("未找到 Ghostty 标签页，已激活 Ghostty")
        case .failure(let error):
            activateApp("com.mitchellh.ghostty")
            return .failed("未找到 Ghostty 标签页，已激活 Ghostty：\(error.description)")
        }
    }

    private func activateApp(_ bundleID: String) {
        DispatchQueue.main.async {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .first?
                .activate(options: [.activateAllWindows])
        }
    }

    private func run(_ script: String, failure: String) -> JumpResult {
        switch AppleScriptRunner.run(script) {
        case .success(let output):
            return output == "ok" ? .success : .failed(failure)
        case .failure(let error):
            return .failed("\(failure)：\(error.description)")
        }
    }

}
