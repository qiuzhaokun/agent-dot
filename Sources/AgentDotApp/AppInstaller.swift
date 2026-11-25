import Foundation
import AppKit

enum AppInstaller {
    static var userApplicationsTarget: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/AgentDot.app")
    }

    static func shouldOfferInstall(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        guard bundleURL.pathExtension == "app" else { return false }
        let path = bundleURL.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL.path
        return !path.hasPrefix(home + "/Applications/")
    }

    static func installToUserApplications() throws -> URL {
        let fileManager = FileManager.default
        let target = userApplicationsTarget
        let parent = target.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: target.path) {
            let backup = parent.appendingPathComponent(
                "AgentDot.previous-\(Int(Date().timeIntervalSince1970)).app"
            )
            try? fileManager.removeItem(at: backup)
            try fileManager.moveItem(at: target, to: backup)
        }

        try fileManager.copyItem(at: Bundle.main.bundleURL, to: target)
        removeQuarantine(at: target)
        return target
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
}
