import Foundation

public protocol ProcessTreeProviding {
    func parentPID(of pid: Int32) -> Int32?
    func processName(of pid: Int32) -> String?
    func executablePath(of pid: Int32) -> String?
    func commandLine(of pid: Int32) -> String?
    func tty(of pid: Int32) -> String?
}

public struct TerminalContextResolver {
    private let environment: [String: String]
    private let processTree: ProcessTreeProviding
    private let currentPID: Int32

    public init(
        environment: [String: String],
        processTree: ProcessTreeProviding,
        currentPID: Int32
    ) {
        self.environment = environment
        self.processTree = processTree
        self.currentPID = currentPID
    }

    public func resolve() -> TerminalContext {
        let ancestry = ancestryPIDs()
        let claudePID = findClaudePID(in: ancestry) ?? 0
        let tty = claudePID > 0 ? normalizeTTY(processTree.tty(of: claudePID)) : nil
        let execPath = claudePID > 0 ? processTree.executablePath(of: claudePID) : nil
        let app = detectApp(ancestry: ancestry)

        return TerminalContext(
            app: app,
            tty: tty,
            itermSessionID: environment["ITERM_SESSION_ID"],
            termSessionID: environment["TERM_SESSION_ID"],
            ghosttySurfaceID: environment["GHOSTTY_SURFACE_ID"],
            weztermPane: environment["WEZTERM_PANE"],
            tmuxPane: environment["TMUX_PANE"],
            claudePID: claudePID,
            claudeExecPath: execPath
        )
    }

    private func ancestryPIDs() -> [Int32] {
        var result: [Int32] = []
        var pid = currentPID
        var seen = Set<Int32>()
        for _ in 0..<20 {
            if pid <= 0 || seen.contains(pid) { break }
            result.append(pid)
            seen.insert(pid)
            guard let parent = processTree.parentPID(of: pid), parent > 0 else { break }
            pid = parent
        }
        return result
    }

    private func findClaudePID(in ancestry: [Int32]) -> Int32? {
        for pid in ancestry {
            let name = processTree.processName(of: pid)?.lowercased() ?? ""
            let command = processTree.commandLine(of: pid)?.lowercased() ?? ""
            let path = processTree.executablePath(of: pid)?.lowercased() ?? ""
            if name == "claude"
                || name.contains("claude")
                || command.contains("/claude")
                || command.contains(" claude")
                || path.contains("/claude") {
                return pid
            }
        }

        for pid in ancestry {
            let name = processTree.processName(of: pid)?.lowercased() ?? ""
            if isShell(name) || name == "dot-hook" || name == "agentdot" {
                continue
            }
            if processTree.tty(of: pid) != nil {
                return pid
            }
        }
        return nil
    }

    private func isShell(_ name: String) -> Bool {
        ["sh", "bash", "zsh", "fish", "dash", "csh", "tcsh", "ksh", "login"].contains(name)
    }

    private func normalizeTTY(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "??", trimmed != "?" else { return nil }
        let candidate = trimmed.hasPrefix("/dev/") ? trimmed : "/dev/\(trimmed)"
        return TerminalIDValidator.isValidTTY(candidate) ? candidate : nil
    }

    private func detectApp(ancestry: [Int32]) -> TerminalApp {
        if let termProgram = environment["TERM_PROGRAM"]?.lowercased() {
            if termProgram == "iterm.app" || termProgram == "iterm" {
                return .iTerm2
            }
            if termProgram == "apple_terminal" {
                return .terminal
            }
            if termProgram == "ghostty" {
                return .ghostty
            }
            if termProgram == "kaku" {
                return .kaku
            }
        }

        for pid in ancestry {
            let path = processTree.executablePath(of: pid)?.lowercased() ?? ""
            if path.contains("/iterm.app/") { return .iTerm2 }
            if path.contains("/terminal.app/") { return .terminal }
            if path.contains("/ghostty.app/") { return .ghostty }
            if path.contains("/kaku.app/") { return .kaku }
        }
        return .unknown
    }
}
