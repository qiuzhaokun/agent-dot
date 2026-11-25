import Foundation
import AgentDotCore

struct FakeProcess {
    var ppid: Int32
    var name: String
    var path: String
    var tty: String?
    var command: String
}

final class FakeProcessTree: ProcessTreeProviding {
    private let processes: [Int32: FakeProcess]

    init(processes: [Int32: FakeProcess]) {
        self.processes = processes
    }

    func parentPID(of pid: Int32) -> Int32? {
        processes[pid]?.ppid
    }

    func processName(of pid: Int32) -> String? {
        processes[pid]?.name
    }

    func executablePath(of pid: Int32) -> String? {
        processes[pid]?.path
    }

    func commandLine(of pid: Int32) -> String? {
        processes[pid]?.command
    }

    func tty(of pid: Int32) -> String? {
        processes[pid]?.tty
    }
}

func runTerminalContextTests() {
    let baseProcesses: [Int32: FakeProcess] = [
        100: FakeProcess(ppid: 90, name: "dot-hook", path: "/Users/example/.agent-dot/bin/dot-hook", tty: nil, command: "dot-hook emit"),
        90: FakeProcess(ppid: 80, name: "sh", path: "/bin/sh", tty: "ttys003", command: "sh -c ..."),
        80: FakeProcess(ppid: 70, name: "claude", path: "/usr/local/bin/claude", tty: "ttys003", command: "claude"),
        70: FakeProcess(ppid: 60, name: "zsh", path: "/bin/zsh", tty: "ttys003", command: "zsh"),
        60: FakeProcess(ppid: 1, name: "iTerm2", path: "/Applications/iTerm.app/Contents/MacOS/iTerm2", tty: nil, command: "iTerm2")
    ]

    runTest("TerminalContext resolves iTerm2") {
        let tree = FakeProcessTree(processes: baseProcesses)
        let env = ["TERM_PROGRAM": "iTerm.app", "ITERM_SESSION_ID": "w0t0p0:UUID"]
        let context = TerminalContextResolver(
            environment: env,
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .iTerm2)
        expectEqual(context.claudePID, 80)
        expectEqual(context.tty, "/dev/ttys003")
        expectEqual(context.itermSessionID, "w0t0p0:UUID")
        expectEqual(context.claudeExecPath, "/usr/local/bin/claude")
    }

    runTest("TerminalContext resolves Terminal") {
        var processes = baseProcesses
        processes[60] = FakeProcess(ppid: 1, name: "Terminal", path: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal", tty: nil, command: "Terminal")
        let tree = FakeProcessTree(processes: processes)
        let env = ["TERM_PROGRAM": "Apple_Terminal"]
        let context = TerminalContextResolver(
            environment: env,
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .terminal)
        expectEqual(context.tty, "/dev/ttys003")
    }

    runTest("TerminalContext resolves Ghostty") {
        var processes = baseProcesses
        processes[60] = FakeProcess(ppid: 1, name: "Ghostty", path: "/Applications/Ghostty.app/Contents/MacOS/ghostty", tty: nil, command: "ghostty")
        let tree = FakeProcessTree(processes: processes)
        let env = ["TERM_PROGRAM": "ghostty", "GHOSTTY_SURFACE_ID": "123456789"]
        let context = TerminalContextResolver(
            environment: env,
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .ghostty)
        expectEqual(context.ghosttySurfaceID, "123456789")
    }

    runTest("TerminalContext resolves Kaku") {
        var processes = baseProcesses
        processes[60] = FakeProcess(ppid: 1, name: "Kaku", path: "/Applications/Kaku.app/Contents/MacOS/kaku", tty: nil, command: "kaku")
        let tree = FakeProcessTree(processes: processes)
        let env = ["TERM_PROGRAM": "Kaku", "WEZTERM_PANE": "3"]
        let context = TerminalContextResolver(
            environment: env,
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .kaku)
        expectEqual(context.weztermPane, "3")
    }

    runTest("TerminalContext detects app from ancestry when env missing") {
        var processes = baseProcesses
        processes[60] = FakeProcess(ppid: 1, name: "Ghostty", path: "/Applications/Ghostty.app/Contents/MacOS/ghostty", tty: nil, command: "ghostty")
        let tree = FakeProcessTree(processes: processes)
        let context = TerminalContextResolver(
            environment: [:],
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .ghostty)
    }

    runTest("TerminalContext unknown terminal") {
        var processes = baseProcesses
        processes[60] = FakeProcess(
            ppid: 1,
            name: "UnknownTerm",
            path: "/Applications/UnknownTerm.app/Contents/MacOS/UnknownTerm",
            tty: nil,
            command: "UnknownTerm"
        )
        let tree = FakeProcessTree(processes: processes)
        let context = TerminalContextResolver(
            environment: [:],
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.app, .unknown)
    }

    runTest("TerminalContext falls back to non-shell ancestor") {
        var processes = baseProcesses
        processes[80] = FakeProcess(ppid: 70, name: "node", path: "/usr/local/bin/node", tty: "ttys003", command: "node /usr/local/bin/claude")
        let tree = FakeProcessTree(processes: processes)
        let context = TerminalContextResolver(
            environment: ["TERM_PROGRAM": "iTerm.app"],
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectEqual(context.claudePID, 80)
        expectEqual(context.tty, "/dev/ttys003")
    }

    runTest("TerminalContext normalizes tty and ignores question marks") {
        var processes = baseProcesses
        processes[80] = FakeProcess(ppid: 70, name: "claude", path: "/usr/local/bin/claude", tty: "??", command: "claude")
        let tree = FakeProcessTree(processes: processes)
        let context = TerminalContextResolver(
            environment: ["TERM_PROGRAM": "iTerm.app"],
            processTree: tree,
            currentPID: 100
        ).resolve()
        expectNil(context.tty)
    }
}
