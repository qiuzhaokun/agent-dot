import Foundation

public enum UpdaterEngineError: Error, CustomStringConvertible {
    case invalidApp(String)
    case wrongBundleID(String)
    case wrongVersion(expected: String, actual: String)
    case missingCurrentApp(String)

    public var description: String {
        switch self {
        case .invalidApp(let path):
            return "invalid app bundle: \(path)"
        case .wrongBundleID(let value):
            return "unexpected bundle id: \(value)"
        case .wrongVersion(let expected, let actual):
            return "unexpected app version: expected \(expected), got \(actual)"
        case .missingCurrentApp(let path):
            return "current app not found: \(path)"
        }
    }
}

public struct UpdaterEngine {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func install(
        currentApp: URL,
        newApp: URL,
        expectedVersion: String,
        backupDirectory: URL
    ) throws {
        let newInfo = try appInfo(at: newApp)
        guard newInfo.bundleID == "dev.agentdot.app" else {
            throw UpdaterEngineError.wrongBundleID(newInfo.bundleID)
        }
        guard newInfo.version == expectedVersion else {
            throw UpdaterEngineError.wrongVersion(
                expected: expectedVersion,
                actual: newInfo.version
            )
        }

        let currentExists = fileManager.fileExists(atPath: currentApp.path)
        let currentVersion = (try? appInfo(at: currentApp))?.version ?? "unknown"
        try fileManager.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let existing = (try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        for item in existing
        where item.lastPathComponent.hasSuffix(".app")
            || item.lastPathComponent.hasSuffix(".app.backup") {
            try? fileManager.removeItem(at: item)
        }

        // .app.backup 不会被 Spotlight/Launchpad 识别成第二个 AgentDot。
        let backupURL = backupDirectory.appendingPathComponent(
            "AgentDot-\(currentVersion)-\(Int(Date().timeIntervalSince1970)).app.backup"
        )
        var movedCurrent = false

        if currentExists {
            try fileManager.moveItem(at: currentApp, to: backupURL)
            movedCurrent = true
        }

        do {
            try fileManager.moveItem(at: newApp, to: currentApp)
        } catch {
            if movedCurrent {
                try? fileManager.moveItem(at: backupURL, to: currentApp)
            }
            throw error
        }
    }

    private func appInfo(at url: URL) throws -> (bundleID: String, version: String) {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: plistURL),
              let bundleID = info["CFBundleIdentifier"] as? String,
              let version = info["CFBundleShortVersionString"] as? String else {
            throw UpdaterEngineError.invalidApp(url.path)
        }
        return (bundleID, version)
    }
}
