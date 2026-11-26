import Foundation

public struct BallAnchor: Codable, Equatable {
    public var screenID: String?
    public var normalizedX: Double
    public var normalizedY: Double

    public init(screenID: String? = nil, normalizedX: Double, normalizedY: Double) {
        self.screenID = screenID
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }
}

public struct AppConfig: Codable, Equatable {
    /// 展开面板列表中一行的高度（pt）。
    public static let listRowHeight: Double = 64
    /// 列表区域最小高度：1 行。
    public static let minListHeight: Double = listRowHeight
    /// 列表区域最大高度：9 行。
    public static let maxListHeight: Double = listRowHeight * 9
    /// 展开面板最小宽度。
    public static let minPanelWidth: Double = 280
    /// 展开面板最大宽度；实际还会受当前屏幕宽度限制。
    public static let maxPanelWidth: Double = 640
    /// 背景透明度下限：保留最小可见度，避免完全隐身。
    public static let minBackgroundOpacity: Double = 10
    public static let maxBackgroundOpacity: Double = 100
    public static let defaultAuthorizationSoundName = "Glass"
    public static let defaultCompletionSoundName = "Ping"

    public var schema: Int
    public var thresholdN: Int
    public var launchAtLogin: Bool
    public var ballAnchor: BallAnchor?
    public var automaticUpdateChecks: Bool
    public var skippedUpdateVersion: String?
    public var lastUpdateCheckAt: Int64?
    public var lastLaunchedVersion: String?
    /// 用户拖拽设置过的列表高度；nil 表示按会话数自动取 min(数量, 5) 行。
    public var expandedListHeight: Double?
    /// 用户拖拽设置过的面板宽度；nil 表示使用默认宽度。
    public var expandedPanelWidth: Double?
    /// 悬浮球背景透明度（百分比，10–100）。
    public var ballBackgroundOpacity: Double
    /// 展开面板背景透明度（百分比，10–100）。
    public var listBackgroundOpacity: Double
    /// 等待授权提示音开关（默认关闭）。
    public var authorizationSoundEnabled: Bool
    /// 任务完成提示音开关（默认关闭）。
    public var completionSoundEnabled: Bool
    /// 等待授权提示音名称。
    public var authorizationSoundName: String
    /// 任务完成提示音名称。
    public var completionSoundName: String

    public init(
        schema: Int,
        thresholdN: Int,
        launchAtLogin: Bool,
        ballAnchor: BallAnchor?,
        automaticUpdateChecks: Bool = true,
        skippedUpdateVersion: String? = nil,
        lastUpdateCheckAt: Int64? = nil,
        lastLaunchedVersion: String? = nil,
        expandedListHeight: Double? = nil,
        expandedPanelWidth: Double? = nil,
        ballBackgroundOpacity: Double = AppConfig.maxBackgroundOpacity,
        listBackgroundOpacity: Double = AppConfig.maxBackgroundOpacity,
        authorizationSoundEnabled: Bool = false,
        completionSoundEnabled: Bool = false,
        authorizationSoundName: String = AppConfig.defaultAuthorizationSoundName,
        completionSoundName: String = AppConfig.defaultCompletionSoundName
    ) {
        self.schema = schema
        self.thresholdN = thresholdN
        self.launchAtLogin = launchAtLogin
        self.ballAnchor = ballAnchor
        self.automaticUpdateChecks = automaticUpdateChecks
        self.skippedUpdateVersion = skippedUpdateVersion
        self.lastUpdateCheckAt = lastUpdateCheckAt
        self.lastLaunchedVersion = lastLaunchedVersion
        self.expandedListHeight = expandedListHeight
        self.expandedPanelWidth = expandedPanelWidth
        self.ballBackgroundOpacity = ballBackgroundOpacity
        self.listBackgroundOpacity = listBackgroundOpacity
        self.authorizationSoundEnabled = authorizationSoundEnabled
        self.completionSoundEnabled = completionSoundEnabled
        self.authorizationSoundName = authorizationSoundName
        self.completionSoundName = completionSoundName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        thresholdN = try container.decodeIfPresent(Int.self, forKey: .thresholdN) ?? 5
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        ballAnchor = try container.decodeIfPresent(BallAnchor.self, forKey: .ballAnchor)
        automaticUpdateChecks = try container.decodeIfPresent(
            Bool.self,
            forKey: .automaticUpdateChecks
        ) ?? true
        skippedUpdateVersion = try container.decodeIfPresent(
            String.self,
            forKey: .skippedUpdateVersion
        )
        lastUpdateCheckAt = try container.decodeIfPresent(
            Int64.self,
            forKey: .lastUpdateCheckAt
        )
        lastLaunchedVersion = try container.decodeIfPresent(
            String.self,
            forKey: .lastLaunchedVersion
        )
        expandedListHeight = try container.decodeIfPresent(
            Double.self,
            forKey: .expandedListHeight
        )
        expandedPanelWidth = try container.decodeIfPresent(
            Double.self,
            forKey: .expandedPanelWidth
        )
        ballBackgroundOpacity = try container.decodeIfPresent(
            Double.self,
            forKey: .ballBackgroundOpacity
        ) ?? Self.maxBackgroundOpacity
        listBackgroundOpacity = try container.decodeIfPresent(
            Double.self,
            forKey: .listBackgroundOpacity
        ) ?? Self.maxBackgroundOpacity
        authorizationSoundEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .authorizationSoundEnabled
        ) ?? false
        completionSoundEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .completionSoundEnabled
        ) ?? false
        authorizationSoundName = try container.decodeIfPresent(
            String.self,
            forKey: .authorizationSoundName
        ) ?? Self.defaultAuthorizationSoundName
        completionSoundName = try container.decodeIfPresent(
            String.self,
            forKey: .completionSoundName
        ) ?? Self.defaultCompletionSoundName
    }

    enum CodingKeys: String, CodingKey {
        case schema
        case thresholdN
        case launchAtLogin
        case ballAnchor
        case automaticUpdateChecks
        case skippedUpdateVersion
        case lastUpdateCheckAt
        case lastLaunchedVersion
        case expandedListHeight
        case expandedPanelWidth
        case ballBackgroundOpacity
        case listBackgroundOpacity
        case authorizationSoundEnabled
        case completionSoundEnabled
        case authorizationSoundName
        case completionSoundName
    }

    public static let `default` = AppConfig(
        schema: 1,
        thresholdN: 5,
        launchAtLogin: true,
        ballAnchor: nil,
        automaticUpdateChecks: true,
        skippedUpdateVersion: nil,
        lastUpdateCheckAt: nil,
        lastLaunchedVersion: nil
    )

    public func clamped() -> AppConfig {
        var config = self
        config.schema = 1
        config.thresholdN = min(max(config.thresholdN, 1), 9)
        if let anchor = config.ballAnchor {
            config.ballAnchor = BallAnchor(
                screenID: anchor.screenID,
                normalizedX: min(max(anchor.normalizedX, 0), 1),
                normalizedY: min(max(anchor.normalizedY, 0), 1)
            )
        }
        if let height = config.expandedListHeight {
            config.expandedListHeight = min(max(height, Self.minListHeight), Self.maxListHeight)
        }
        if let width = config.expandedPanelWidth {
            config.expandedPanelWidth = min(max(width, Self.minPanelWidth), Self.maxPanelWidth)
        }
        config.ballBackgroundOpacity = min(
            max(config.ballBackgroundOpacity, Self.minBackgroundOpacity),
            Self.maxBackgroundOpacity
        )
        config.listBackgroundOpacity = min(
            max(config.listBackgroundOpacity, Self.minBackgroundOpacity),
            Self.maxBackgroundOpacity
        )
        return config
    }
}

public struct ConfigStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }
        return config.clamped()
    }

    public func save(_ config: AppConfig) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config.clamped())
        try data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
