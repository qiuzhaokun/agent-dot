import Foundation

public struct InstallReport: Equatable {
    public var backupURL: URL?
    public var eventsInstalled: [String]
    public var skippedEvents: [String]

    public init(backupURL: URL?, eventsInstalled: [String], skippedEvents: [String]) {
        self.backupURL = backupURL
        self.eventsInstalled = eventsInstalled
        self.skippedEvents = skippedEvents
    }
}

public enum SettingsMergerError: Error, CustomStringConvertible {
    case invalidJSON(String)
    case unexpectedHooksType
    case validationFailed(String)

    public var description: String {
        switch self {
        case .invalidJSON(let detail):
            return "settings.json is not valid JSON: \(detail)"
        case .unexpectedHooksType:
            return "settings.json hooks value is not an object"
        case .validationFailed(let backupPath):
            return "settings.json validation failed after write; backup: \(backupPath)"
        }
    }
}

public struct SettingsMerger {
    public static let hookMarker = ".agent-dot/bin/dot-hook"
    public static let events = [
        "SessionStart",
        "UserPromptSubmit",
        "PreToolUse",
        "PostToolUse",
        "PermissionRequest",
        "PermissionDenied",
        "Notification",
        "Stop",
        "StopFailure",
        "SessionEnd"
    ]

    public let settingsURL: URL
    public let hookCommand: String

    public init(settingsURL: URL, hookCommand: String) {
        self.settingsURL = settingsURL
        self.hookCommand = hookCommand
    }

    public func isInstalled() -> Bool {
        guard let settings = try? readSettings() else { return false }
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return Self.events.allSatisfy { event in
            guard let groups = hooks[event] as? [[String: Any]] else { return false }
            return commands(in: groups).contains { $0.contains(Self.hookMarker) }
        }
    }

    public func install(now: Date = Date()) throws -> InstallReport {
        let existing = try readSettings()
        let backup = try makeBackup(now: now)
        var settings = existing ?? [:]
        var hooks = try hooksDictionary(from: settings)
        var installed: [String] = []

        for event in Self.events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups = groups.compactMap { group in
                var group = group
                let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter { handler in
                    !isOurs(handler)
                }
                if handlers.isEmpty {
                    return nil
                }
                group["hooks"] = handlers
                return group
            }
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": hookCommand,
                    "timeout": 5
                ]]
            ])
            hooks[event] = groups
            installed.append(event)
        }

        settings["hooks"] = hooks
        try writeSettings(settings)

        guard isInstalled() else {
            throw SettingsMergerError.validationFailed(
                backup?.path ?? settingsURL.path
            )
        }
        return InstallReport(backupURL: backup, eventsInstalled: installed, skippedEvents: [])
    }

    public func uninstall() throws {
        guard var settings = try readSettings() else { return }
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in Self.events {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            groups = groups.compactMap { group in
                var group = group
                let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter { handler in
                    !isOurs(handler)
                }
                if handlers.isEmpty {
                    return nil
                }
                group["hooks"] = handlers
                return group
            }
            if groups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = groups
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }
        try writeSettings(settings)
    }

    private func isOurs(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(Self.hookMarker) == true
    }

    private func commands(in groups: [[String: Any]]) -> [String] {
        groups.flatMap { group in
            (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
        }
    }

    private func hooksDictionary(from settings: [String: Any]) throws -> [String: Any] {
        if let hooks = settings["hooks"] {
            guard let hooks = hooks as? [String: Any] else {
                throw SettingsMergerError.unexpectedHooksType
            }
            return hooks
        }
        return [:]
    }

    private func readSettings() throws -> [String: Any]? {
        let target = resolvedTarget()
        guard FileManager.default.fileExists(atPath: target.path) else {
            return nil
        }
        let data = try Data(contentsOf: target)
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let settings = object as? [String: Any] else {
                throw SettingsMergerError.invalidJSON("top-level value is not an object")
            }
            return settings
        } catch let error as SettingsMergerError {
            throw error
        } catch {
            throw SettingsMergerError.invalidJSON(error.localizedDescription)
        }
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let target = resolvedTarget()
        let directory = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: target, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: target.path
        )
    }

    private func makeBackup(now: Date) throws -> URL? {
        let target = resolvedTarget()
        guard FileManager.default.fileExists(atPath: target.path) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let stamp = formatter.string(from: now)
        let directory = target.deletingLastPathComponent()
        let baseName = "\(target.lastPathComponent).agentdot-backup-\(stamp)"
        var candidate = directory.appendingPathComponent(baseName)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(counter)")
            counter += 1
        }
        try FileManager.default.copyItem(at: target, to: candidate)
        return candidate
    }

    private func resolvedTarget() -> URL {
        settingsURL.resolvingSymlinksInPath()
    }
}
