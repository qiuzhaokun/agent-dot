import Foundation

public enum TerminalIDValidator {
    public static func isValidTTY(_ value: String) -> Bool {
        value.range(of: "^/dev/tty[a-zA-Z0-9]+$", options: .regularExpression) != nil
    }

    public static func isValidSessionUUID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9-]{8,64}$", options: .regularExpression) != nil
    }

    public static func isValidPaneID(_ value: String) -> Bool {
        value.range(of: "^[0-9]{1,20}$", options: .regularExpression) != nil
    }

    public static func isValidSurfaceID(_ value: String) -> Bool {
        value.range(of: "^[0-9a-fA-F]{1,32}$", options: .regularExpression) != nil
    }

    public static func itermUUID(from rawValue: String) -> String? {
        guard let colon = rawValue.lastIndex(of: ":") else { return nil }
        let uuid = String(rawValue[rawValue.index(after: colon)...])
        return isValidSessionUUID(uuid) ? uuid : nil
    }

    public static func escapeAppleScript(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.components(separatedBy: CharacterSet.controlCharacters).joined()
        return result
    }
}
