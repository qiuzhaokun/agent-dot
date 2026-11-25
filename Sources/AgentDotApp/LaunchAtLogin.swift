import Foundation
import Darwin

enum LaunchAtLogin {
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/dev.agentdot.app.plist")
    }

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func isEnabled(for appPath: URL) -> Bool {
        guard let plist = NSDictionary(contentsOf: plistURL),
              let arguments = plist["ProgramArguments"] as? [String],
              let program = arguments.first else {
            return false
        }
        return URL(fileURLWithPath: program).standardizedFileURL.path
            == appPath.standardizedFileURL.path
    }

    static func enable(appPath: URL) throws {
        let plist: [String: Any] = [
            "Label": "dev.agentdot.app",
            "ProgramArguments": [appPath.path],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: .atomic)

        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        _ = runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func disable() throws {
        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
