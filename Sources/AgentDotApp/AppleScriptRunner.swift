import Foundation
import AppKit

enum AppleScriptError: Error, CustomStringConvertible {
    case compile(String)
    case execution(String)

    var description: String {
        switch self {
        case .compile(let message):
            return "AppleScript compile failed: \(message)"
        case .execution(let message):
            return "AppleScript execution failed: \(message)"
        }
    }
}

enum AppleScriptRunner {
    private static let executionQueue = DispatchQueue(
        label: "dev.agentdot.applescript"
    )

    static func run(_ source: String) -> Result<String, AppleScriptError> {
        executionQueue.sync {
            execute(source)
        }
    }

    private static func execute(_ source: String) -> Result<String, AppleScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.compile("cannot create NSAppleScript"))
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return .failure(.execution(error.description))
        }
        return .success(descriptor.stringValue ?? "")
    }
}
