import Foundation
import Darwin
import AgentDotCore

private struct Options {
    var waitPID: Int32
    var currentApp: URL
    var newApp: URL
    var expectedVersion: String
    var backupDirectory: URL
    var logURL: URL
    var relaunch: Bool
}

private let usage = """
Usage: AgentDotUpdater --wait-pid PID --current-app PATH --new-app PATH --expected-version VERSION
  [--backup-dir PATH] [--log PATH] [--no-relaunch]
"""

private func parseOptions() -> Options? {
    var waitPID: Int32 = 0
    var currentApp: String?
    var newApp: String?
    var expectedVersion: String?
    let home = FileManager.default.homeDirectoryForCurrentUser
    var backupDirectory = home.appendingPathComponent(
        "Library/Application Support/AgentDot/Backups"
    )
    var logURL = home.appendingPathComponent(
        "Library/Application Support/AgentDot/logs/updater.log"
    )
    var relaunch = true

    let arguments = Array(CommandLine.arguments.dropFirst())
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func value() -> String? {
            index + 1 < arguments.count ? arguments[index + 1] : nil
        }
        switch argument {
        case "--wait-pid":
            guard let raw = value(), let parsed = Int32(raw) else { return nil }
            waitPID = parsed
            index += 2
        case "--current-app":
            guard let parsed = value() else { return nil }
            currentApp = parsed
            index += 2
        case "--new-app":
            guard let parsed = value() else { return nil }
            newApp = parsed
            index += 2
        case "--expected-version":
            guard let parsed = value() else { return nil }
            expectedVersion = parsed
            index += 2
        case "--backup-dir":
            guard let parsed = value() else { return nil }
            backupDirectory = URL(fileURLWithPath: parsed)
            index += 2
        case "--log":
            guard let parsed = value() else { return nil }
            logURL = URL(fileURLWithPath: parsed)
            index += 2
        case "--no-relaunch":
            relaunch = false
            index += 1
        default:
            return nil
        }
    }

    guard let currentApp, let newApp, let expectedVersion else {
        return nil
    }
    return Options(
        waitPID: waitPID,
        currentApp: URL(fileURLWithPath: currentApp),
        newApp: URL(fileURLWithPath: newApp),
        expectedVersion: expectedVersion,
        backupDirectory: backupDirectory,
        logURL: logURL,
        relaunch: relaunch
    )
}

private func appendLog(_ message: String, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    let stamp = ISO8601DateFormatter().string(from: Date())
    guard let data = "[\(stamp)] \(message)\n".data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: url.path),
       let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: url)
    }
    try? FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: url.path
    )
}

private func waitForExit(pid: Int32, timeout: TimeInterval) -> Bool {
    guard pid > 0 else { return true }
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if kill(pid, 0) != 0 && errno == ESRCH {
            return true
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
    return kill(pid, 0) != 0 && errno == ESRCH
}

private func removeQuarantine(at url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    process.arguments = ["-dr", "com.apple.quarantine", url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

private func relaunch(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
}

guard let options = parseOptions() else {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}

appendLog(
    "updater started pid=\(getpid()) wait=\(options.waitPID) current=\(options.currentApp.path)",
    to: options.logURL
)

guard waitForExit(pid: options.waitPID, timeout: 60) else {
    appendLog("timed out waiting for app to exit", to: options.logURL)
    exit(1)
}

do {
    try UpdaterEngine().install(
        currentApp: options.currentApp,
        newApp: options.newApp,
        expectedVersion: options.expectedVersion,
        backupDirectory: options.backupDirectory
    )
} catch {
    appendLog("install failed: \(error)", to: options.logURL)
    exit(1)
}

removeQuarantine(at: options.currentApp)
if options.relaunch {
    relaunch(options.currentApp)
    appendLog("update installed and relaunched", to: options.logURL)
} else {
    appendLog("update installed (relaunch skipped)", to: options.logURL)
}
exit(0)
