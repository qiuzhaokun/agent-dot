import Foundation

public struct SessionUIState: Codable, Equatable {
    public var acknowledgedAt: Int64?
    public var waitingSinceAtAck: Int64?

    public init(
        acknowledgedAt: Int64? = nil,
        waitingSinceAtAck: Int64? = nil
    ) {
        self.acknowledgedAt = acknowledgedAt
        self.waitingSinceAtAck = waitingSinceAtAck
    }
}

public struct UIState: Codable, Equatable {
    public var schema: Int
    public var sessions: [String: SessionUIState]

    public init(
        schema: Int = 1,
        sessions: [String: SessionUIState] = [:]
    ) {
        self.schema = schema
        self.sessions = sessions
    }
}

public struct UIStateStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> UIState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(UIState.self, from: data) else {
            return UIState()
        }
        return state
    }

    public func save(_ state: UIState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    public func acknowledge(
        sessionID: String,
        at timestamp: Int64,
        waitingSince: Int64
    ) {
        var state = load()
        state.sessions[sessionID] = SessionUIState(
            acknowledgedAt: timestamp,
            waitingSinceAtAck: waitingSince
        )
        try? save(state)
    }

    public func clearAcknowledgment(sessionID: String) {
        var state = load()
        state.sessions[sessionID] = SessionUIState(
            acknowledgedAt: nil,
            waitingSinceAtAck: nil
        )
        try? save(state)
    }

    public func prune(existingSessionIDs: Set<String>) {
        var state = load()
        state.sessions = state.sessions.filter { existingSessionIDs.contains($0.key) }
        try? save(state)
    }
}
