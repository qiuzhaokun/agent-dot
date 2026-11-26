import Foundation
import Darwin
import AppKit

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
            == executableURL(for: appPath).path
    }

    static func enable(appPath: URL) throws {
        let plist: [String: Any] = [
            "Label": "dev.agentdot.app",
            "ProgramArguments": [executableURL(for: appPath).path],
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

        // 应用正在运行时不要把「开机自启」变成「立刻再启动一个实例」；
        // 写入 plist 后，下次登录由 launchd 自动加载。
        guard !isAppRunning else { return }
        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        _ = runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func disable() throws {
        if !isAppRunning {
            _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        }
        try? FileManager.default.removeItem(at: plistURL)
    }

    private static var isAppRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.agentdot.app"
        ).isEmpty
    }

    private static func executableURL(for appPath: URL) -> URL {
        let candidate = appPath.appendingPathComponent("Contents/MacOS/AgentDot")
        return FileManager.default.isExecutableFile(atPath: candidate.path)
            ? candidate.standardizedFileURL
            : appPath.standardizedFileURL
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
