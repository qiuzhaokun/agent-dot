import Foundation

public enum AgentDotPaths {
    public static func stateDirectory(
        environment: [String: String],
        homeDirectory: URL
    ) -> URL {
        if let override = environment["AGENTDOT_STATE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(
            "Library/Application Support/AgentDot",
            isDirectory: true
        )
    }

    public static var stateDirectory: URL {
        stateDirectory(
            environment: ProcessInfo.processInfo.environment,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    public static var sessionsDirectory: URL {
        stateDirectory.appendingPathComponent("sessions", isDirectory: true)
    }

    public static var configURL: URL {
        stateDirectory.appendingPathComponent("config.json")
    }

    public static var uiStateURL: URL {
        stateDirectory.appendingPathComponent("ui-state.json")
    }

    public static var logsDirectory: URL {
        stateDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    public static var hookLogURL: URL {
        logsDirectory.appendingPathComponent("hook.log")
    }

    public static var helperURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-dot/bin/dot-hook")
    }

    public static func ensureDirectories() throws {
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        try fm.createDirectory(
            at: stateDirectory,
            withIntermediateDirectories: true,
            attributes: attributes
        )
        try? fm.setAttributes(attributes, ofItemAtPath: stateDirectory.path)
        try fm.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true,
            attributes: attributes
        )
        try? fm.setAttributes(attributes, ofItemAtPath: sessionsDirectory.path)
        try fm.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true,
            attributes: attributes
        )
        try? fm.setAttributes(attributes, ofItemAtPath: logsDirectory.path)
    }
}
