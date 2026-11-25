import Foundation
import AppKit
import AgentDotCore

enum AppInstallerError: Error, CustomStringConvertible {
    case newerVersionInstalled(String)
    case sameVersionInstalled(String)

    var description: String {
        switch self {
        case .newerVersionInstalled(let version):
            return "~/Applications 已安装更新的 \(version)，请直接打开它，避免降级"
        case .sameVersionInstalled(let version):
            return "~/Applications 已安装相同版本 \(version)，请直接打开它"
        }
    }
}

enum AppInstaller {
    static var userApplicationsTarget: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/AgentDot.app")
    }

    static var backupsDirectory: URL {
        AgentDotPaths.stateDirectory
            .appendingPathComponent("Backups", isDirectory: true)
    }

    static func shouldOfferInstall(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        guard bundleURL.pathExtension == "app" else { return false }
        guard !isInsideUserApplications(bundleURL) else { return false }

        guard let targetVersion = appVersion(at: userApplicationsTarget),
              let runningVersion = appVersion(at: bundleURL),
              let target = SemanticVersion(targetVersion),
              let running = SemanticVersion(runningVersion) else {
            return true
        }
        // 已经装了相同或更新的版本时，不要再用当前副本覆盖，避免降级和重复备份。
        return target < running
    }

    static func installToUserApplications() throws -> URL {
        let fileManager = FileManager.default
        let target = userApplicationsTarget
        let parent = target.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
        cleanupLegacyBackups()

        let runningVersion = appVersion(at: Bundle.main.bundleURL)
        if let targetVersion = appVersion(at: target),
           let runningVersion {
            if let target = SemanticVersion(targetVersion),
               let running = SemanticVersion(runningVersion) {
                if target > running {
                    throw AppInstallerError.newerVersionInstalled(targetVersion)
                }
                if target == running {
                    throw AppInstallerError.sameVersionInstalled(targetVersion)
                }
            } else if targetVersion == runningVersion {
                throw AppInstallerError.sameVersionInstalled(targetVersion)
            }
        }

        if fileManager.fileExists(atPath: target.path) {
            let backups = backupsDirectory
            try fileManager.createDirectory(
                at: backups,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let version = appVersion(at: target) ?? "unknown"
            let backup = backups.appendingPathComponent(
                "AgentDot-\(version)-\(Int(Date().timeIntervalSince1970)).app.backup"
            )
            try? fileManager.removeItem(at: backup)
            try fileManager.moveItem(at: target, to: backup)
        }

        try fileManager.copyItem(at: Bundle.main.bundleURL, to: target)
        removeQuarantine(at: target)
        return target
    }

    /// 把旧版本安装器留在 ~/Applications 的 .app 备份，以及 Backups 里的 .app，
    /// 迁移成 .app.backup，避免被 Spotlight/Launchpad 当成可启动的重复 App。
    static func cleanupLegacyBackups() {
        let fileManager = FileManager.default
        let backups = backupsDirectory
        try? fileManager.createDirectory(
            at: backups,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let appsParent = userApplicationsTarget.deletingLastPathComponent()
        let appItems = (try? fileManager.contentsOfDirectory(
            at: appsParent,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in appItems
        where url.lastPathComponent.hasPrefix("AgentDot.previous-")
            && url.pathExtension == "app" {
            let destination = backups.appendingPathComponent(
                url.lastPathComponent + ".backup"
            )
            try? fileManager.removeItem(at: destination)
            try? fileManager.moveItem(at: url, to: destination)
        }

        let backupItems = (try? fileManager.contentsOfDirectory(
            at: backups,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in backupItems where url.pathExtension == "app" {
            let destination = url.appendingPathExtension("backup")
            try? fileManager.removeItem(at: destination)
            try? fileManager.moveItem(at: url, to: destination)
        }
    }

    static func removeQuarantine(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    static func relaunch(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { _, _ in }
    }

    private static func appVersion(at url: URL) -> String? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        let info = NSDictionary(contentsOf: plist)
        return info?["CFBundleShortVersionString"] as? String
    }

    private static func isInsideUserApplications(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL.path
        return path.hasPrefix(home + "/Applications/")
    }
}
