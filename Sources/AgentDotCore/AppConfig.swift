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
    public var schema: Int
    public var thresholdN: Int
    public var launchAtLogin: Bool
    public var ballAnchor: BallAnchor?
    public var automaticUpdateChecks: Bool
    public var skippedUpdateVersion: String?
    public var lastUpdateCheckAt: Int64?
    public var lastLaunchedVersion: String?

    public init(
        schema: Int,
        thresholdN: Int,
        launchAtLogin: Bool,
        ballAnchor: BallAnchor?,
        automaticUpdateChecks: Bool = true,
        skippedUpdateVersion: String? = nil,
        lastUpdateCheckAt: Int64? = nil,
        lastLaunchedVersion: String? = nil
    ) {
        self.schema = schema
        self.thresholdN = thresholdN
        self.launchAtLogin = launchAtLogin
        self.ballAnchor = ballAnchor
        self.automaticUpdateChecks = automaticUpdateChecks
        self.skippedUpdateVersion = skippedUpdateVersion
        self.lastUpdateCheckAt = lastUpdateCheckAt
        self.lastLaunchedVersion = lastLaunchedVersion
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
