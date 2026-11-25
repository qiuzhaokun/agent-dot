import Foundation
import AppKit

enum KakuCLI {
    static func locate() -> String {
        let direct = "/Applications/Kaku.app/Contents/MacOS/kaku"
        if FileManager.default.isExecutableFile(atPath: direct) {
            return direct
        }
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "fun.tw93.kaku"
        ) {
            return appURL.appendingPathComponent("Contents/MacOS/kaku").path
        }
        return direct
    }

    static func run(
        _ arguments: [String],
        timeout: TimeInterval = 1.0
    ) -> (status: Int32, stdout: String)? {
        let cli = locate()
        guard FileManager.default.isExecutableFile(atPath: cli) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in
            group.leave()
        }

        do {
            try process.run()
        } catch {
            group.leave()
            return nil
        }

        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout)
    }
}
