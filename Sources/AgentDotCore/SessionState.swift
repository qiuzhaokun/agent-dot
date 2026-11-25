import Foundation

public enum SessionPhase: String, Codable, CaseIterable {
    case idle
    case running
    case waitingPermission = "waiting_permission"
    case done
    case error
    case ended
}

public enum TerminalApp: String, Codable, CaseIterable {
    case iTerm2 = "iTerm2"
    case terminal = "Terminal"
    case ghostty = "Ghostty"
    case kaku = "Kaku"
    case unknown = "unknown"

    public var bundleIdentifier: String? {
        switch self {
        case .iTerm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .ghostty: return "com.mitchellh.ghostty"
        case .kaku: return "fun.tw93.kaku"
        case .unknown: return nil
        }
    }
}

public struct TerminalContext: Codable, Equatable {
    public var app: TerminalApp
    public var tty: String?
    public var itermSessionID: String?
    public var termSessionID: String?
    public var ghosttySurfaceID: String?
    public var weztermPane: String?
    public var tmuxPane: String?
    public var claudePID: Int32
    public var claudeExecPath: String?

    public init(
        app: TerminalApp,
        tty: String? = nil,
        itermSessionID: String? = nil,
        termSessionID: String? = nil,
        ghosttySurfaceID: String? = nil,
        weztermPane: String? = nil,
        tmuxPane: String? = nil,
        claudePID: Int32 = 0,
        claudeExecPath: String? = nil
    ) {
        self.app = app
        self.tty = tty
        self.itermSessionID = itermSessionID
        self.termSessionID = termSessionID
        self.ghosttySurfaceID = ghosttySurfaceID
        self.weztermPane = weztermPane
        self.tmuxPane = tmuxPane
        self.claudePID = claudePID
        self.claudeExecPath = claudeExecPath
    }

    enum CodingKeys: String, CodingKey {
        case app
        case tty
        case itermSessionID = "iterm_session_id"
        case termSessionID = "term_session_id"
        case ghosttySurfaceID = "ghostty_surface_id"
        case weztermPane = "wezterm_pane"
        case tmuxPane = "tmux_pane"
        case claudePID = "claude_pid"
        case claudeExecPath = "claude_exec_path"
    }
}

public struct SessionState: Codable, Equatable {
    public var schema: Int
    public var sessionID: String
    public var cwd: String
    public var projectName: String
    /// 运行时从 Claude Code 会话注册表读取的 /rename 名称；不写入会话文件。
    public var displayName: String?
    public var state: SessionPhase
    public var currentTool: String?
    public var notificationType: String?
    public var errorKind: String?
    public var startedAt: Int64
    public var updatedAt: Int64
    public var lastActivityAt: Int64
    public var turnStartedAt: Int64?
    public var turnEndedAt: Int64?
    public var waitingSince: Int64?
    public var terminal: TerminalContext

    public init(
        schema: Int,
        sessionID: String,
        cwd: String,
        projectName: String,
        state: SessionPhase,
        currentTool: String? = nil,
        notificationType: String? = nil,
        errorKind: String? = nil,
        startedAt: Int64,
        updatedAt: Int64,
        lastActivityAt: Int64,
        turnStartedAt: Int64? = nil,
        turnEndedAt: Int64? = nil,
        waitingSince: Int64? = nil,
        terminal: TerminalContext,
        displayName: String? = nil
    ) {
        self.schema = schema
        self.sessionID = sessionID
        self.cwd = cwd
        self.projectName = projectName
        self.state = state
        self.currentTool = currentTool
        self.notificationType = notificationType
        self.errorKind = errorKind
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.lastActivityAt = lastActivityAt
        self.turnStartedAt = turnStartedAt
        self.turnEndedAt = turnEndedAt
        self.waitingSince = waitingSince
        self.terminal = terminal
        self.displayName = displayName
    }

    public static func projectName(
        forCWD cwd: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        let trimmed = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unknown" }
        let standardized = (trimmed as NSString).standardizingPath
        let home = (homeDirectory as NSString).standardizingPath
        if standardized == home { return "~" }
        let last = (standardized as NSString).lastPathComponent
        return last.isEmpty ? "unknown" : last
    }

    enum CodingKeys: String, CodingKey {
        case schema
        case sessionID = "session_id"
        case cwd
        case projectName = "project_name"
        case displayName = "display_name"
        case state
        case currentTool = "current_tool"
        case notificationType = "notification_type"
        case errorKind = "error_kind"
        case startedAt = "started_at"
        case updatedAt = "updated_at"
        case lastActivityAt = "last_activity_at"
        case turnStartedAt = "turn_started_at"
        case turnEndedAt = "turn_ended_at"
        case waitingSince = "waiting_since"
        case terminal
    }
}
