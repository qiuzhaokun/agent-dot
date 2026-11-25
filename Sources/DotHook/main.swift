import Foundation
import Darwin
import AgentDotCore

private func settingsURL() -> URL {
    if let override = ProcessInfo.processInfo.environment["AGENTDOT_SETTINGS_PATH"],
       !override.isEmpty {
        return URL(fileURLWithPath: override)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
}

private func makeHandler() -> HookHandler {
    let store = SessionFileStore(directory: AgentDotPaths.sessionsDirectory)
    let resolver = TerminalContextResolver(
        environment: ProcessInfo.processInfo.environment,
        processTree: LiveProcessTree(),
        currentPID: getpid()
    )
    return HookHandler(store: store, resolver: resolver)
}

private func emit() -> Never {
    let input = FileHandle.standardInput.readDataToEndOfFile()
    let now = Int64(Date().timeIntervalSince1970)
    _ = makeHandler().handle(input: input, now: now)
    exit(0)
}

private func installHooks() -> Never {
    let merger = SettingsMerger(
        settingsURL: settingsURL(),
        hookCommand: "\(AgentDotPaths.helperURL.path) emit"
    )
    do {
        let report = try merger.install()
        print("Installed hooks for \(report.eventsInstalled.count) events.")
        if let backup = report.backupURL {
            print("Backup: \(backup.path)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("install-hooks failed: \(error)\n".utf8))
        exit(1)
    }
}

private func uninstallHooks() -> Never {
    let merger = SettingsMerger(
        settingsURL: settingsURL(),
        hookCommand: "\(AgentDotPaths.helperURL.path) emit"
    )
    do {
        try merger.uninstall()
        print("Removed AgentDot hooks.")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("uninstall-hooks failed: \(error)\n".utf8))
        exit(1)
    }
}

private func status() -> Never {
    let store = SessionFileStore(directory: AgentDotPaths.sessionsDirectory)
    for state in store.loadAll().sorted(by: { $0.updatedAt > $1.updatedAt }) {
        print("\(state.sessionID)\t\(state.projectName)\t\(state.state.rawValue)\t\(state.updatedAt)")
    }
    exit(0)
}

private let usage = """
Usage: dot-hook <command>

Commands:
  emit            read one hook payload from stdin and update session state
  install-hooks   merge AgentDot hooks into ~/.claude/settings.json
  uninstall-hooks remove AgentDot hooks from ~/.claude/settings.json
  status          list current session states
  version         print version
"""

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "emit":
    emit()
case "install-hooks":
    installHooks()
case "uninstall-hooks":
    uninstallHooks()
case "status":
    status()
case "version":
    print("AgentDot 0.1.2")
    exit(0)
default:
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(0)
}
