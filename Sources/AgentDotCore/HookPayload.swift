import Foundation

public struct HookPayload: Decodable, Equatable {
    public var sessionID: String
    public var cwd: String?
    public var hookEventName: String
    public var source: String?
    public var reason: String?
    public var toolName: String?
    public var toolUseID: String?
    public var notificationType: String?
    public var errorType: String?

    public init(
        sessionID: String,
        cwd: String? = nil,
        hookEventName: String,
        source: String? = nil,
        reason: String? = nil,
        toolName: String? = nil,
        toolUseID: String? = nil,
        notificationType: String? = nil,
        errorType: String? = nil
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.source = source
        self.reason = reason
        self.toolName = toolName
        self.toolUseID = toolUseID
        self.notificationType = notificationType
        self.errorType = errorType
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case source
        case reason
        case toolName = "tool_name"
        case toolUseID = "tool_use_id"
        case notificationType = "notification_type"
        case errorType = "error_type"
    }
}
