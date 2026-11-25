import Foundation
import AgentDotCore

private let hookCommand = "/Users/example/.agent-dot/bin/dot-hook emit"
private let ccStatusCommand = "/Users/example/.config/iterm2/cc-status"

private func readJSON(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data)
    return try unwrap(object as? [String: Any])
}

private func commands(in groups: [[String: Any]]) -> [String] {
    groups.flatMap { group in
        (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
    }
}

func runSettingsMergerTests() {
    let date = Date(timeIntervalSince1970: 1_000)

    func makeSettings() throws -> (URL, SettingsMerger) {
        let directory = TestSupport.tempDirectory()
        let url = directory.appendingPathComponent("settings.json")
        let original = """
        {"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"\(ccStatusCommand)"}]}]},"model":"x"}
        """
        try original.write(to: url, atomically: true, encoding: .utf8)
        return (url, SettingsMerger(settingsURL: url, hookCommand: hookCommand))
    }

    runTest("SettingsMerger install preserves existing hooks and backs up") {
        let (url, merger) = try makeSettings()
        let report = try merger.install(now: date)
        let object = try readJSON(url)
        expectEqual(object["model"] as? String, "x")
        let hooks = try unwrap(object["hooks"] as? [String: Any])
        let groups = try unwrap(hooks["PreToolUse"] as? [[String: Any]])
        expectEqual(groups.count, 2)
        let all = commands(in: groups)
        expect(all.contains(ccStatusCommand))
        expect(all.contains(hookCommand))
        let backup = try unwrap(report.backupURL)
        expect(FileManager.default.fileExists(atPath: backup.path))
    }

    runTest("SettingsMerger install is idempotent") {
        let (url, merger) = try makeSettings()
        _ = try merger.install(now: date)
        _ = try merger.install(now: date.addingTimeInterval(1))
        let object = try readJSON(url)
        let hooks = try unwrap(object["hooks"] as? [String: Any])
        let groups = try unwrap(hooks["PreToolUse"] as? [[String: Any]])
        expectEqual(groups.count, 2)
        let ours = commands(in: groups).filter { $0.contains(SettingsMerger.hookMarker) }
        expectEqual(ours.count, 1)
    }

    runTest("SettingsMerger install covers all events") {
        let (url, merger) = try makeSettings()
        _ = try merger.install(now: date)
        let object = try readJSON(url)
        let hooks = try unwrap(object["hooks"] as? [String: Any])
        for event in SettingsMerger.events {
            let groups = try unwrap(hooks[event] as? [[String: Any]], "missing event \(event)")
            let ours = commands(in: groups).filter { $0.contains(SettingsMerger.hookMarker) }
            expectEqual(ours.count, 1, "event \(event)")
        }
    }

    runTest("SettingsMerger uninstall removes only our handlers") {
        let (url, merger) = try makeSettings()
        _ = try merger.install(now: date)
        try merger.uninstall()
        let object = try readJSON(url)
        expectEqual(object["model"] as? String, "x")
        let hooks = try unwrap(object["hooks"] as? [String: Any])
        let groups = try unwrap(hooks["PreToolUse"] as? [[String: Any]])
        expectEqual(groups.count, 1)
        let all = commands(in: groups)
        expect(all.contains(ccStatusCommand))
        expect(!all.contains(hookCommand))
    }

    runTest("SettingsMerger invalid JSON is not modified") {
        let directory = TestSupport.tempDirectory()
        let url = directory.appendingPathComponent("settings.json")
        let original = "{not json".data(using: .utf8)!
        try original.write(to: url)
        let merger = SettingsMerger(settingsURL: url, hookCommand: hookCommand)
        expectThrows { _ = try merger.install(now: date) }
        expectEqual(try Data(contentsOf: url), original)
    }

    runTest("SettingsMerger writes symlink target and keeps link") {
        let directory = TestSupport.tempDirectory()
        let real = directory.appendingPathComponent("settings.json")
        let original = """
        {"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"\(ccStatusCommand)"}]}]}}
        """
        try original.write(to: real, atomically: true, encoding: .utf8)
        let link = directory.appendingPathComponent("settings-link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let merger = SettingsMerger(settingsURL: link, hookCommand: hookCommand)
        _ = try merger.install(now: date)

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        expect(!destination.isEmpty)
        let object = try readJSON(real)
        let hooks = try unwrap(object["hooks"] as? [String: Any])
        let groups = try unwrap(hooks["PreToolUse"] as? [[String: Any]])
        expect(commands(in: groups).contains(hookCommand))
    }

    runTest("SettingsMerger isInstalled detects missing and installed") {
        let (_, merger) = try makeSettings()
        expect(!merger.isInstalled())
        _ = try merger.install(now: date)
        expect(merger.isInstalled())
        try merger.uninstall()
        expect(!merger.isInstalled())
    }
}
