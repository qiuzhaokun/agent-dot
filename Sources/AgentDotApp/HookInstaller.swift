import Foundation
import AgentDotCore

enum HookInstallerError: Error, CustomStringConvertible {
    case helperMissing

    var description: String {
        switch self {
        case .helperMissing:
            return "未找到 app 内置的 dot-hook（请先运行 scripts/install.sh）"
        }
    }
}

enum HookInstaller {
    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static func installHelperIfNeeded() throws {
        let fileManager = FileManager.default
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/dot-hook")
        guard fileManager.isExecutableFile(atPath: bundled.path) else {
            throw HookInstallerError.helperMissing
        }

        let destination = AgentDotPaths.helperURL
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".dot-hook.tmp-\(UUID().uuidString)")
        try fileManager.copyItem(at: bundled, to: temporary)
        do {
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: temporary.path
            )
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    static func ensureHooks() throws -> InstallReport {
        let merger = SettingsMerger(
            settingsURL: settingsURL,
            hookCommand: "\(AgentDotPaths.helperURL.path) emit"
        )
        return try merger.install()
    }

    static func isInstalled() -> Bool {
        guard FileManager.default.isExecutableFile(
            atPath: AgentDotPaths.helperURL.path
        ) else {
            return false
        }
        let merger = SettingsMerger(
            settingsURL: settingsURL,
            hookCommand: "\(AgentDotPaths.helperURL.path) emit"
        )
        return merger.isInstalled()
    }
}
