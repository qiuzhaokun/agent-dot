import Foundation

public enum UpdateManifestError: Error, CustomStringConvertible {
    case invalidVersion(String)
    case notNewer
    case requiresNewerMacOS(String)
    case invalidURL(String)
    case invalidSHA256
    case invalidSignature
    case sizeTooLarge(Int)

    public var description: String {
        switch self {
        case .invalidVersion(let value):
            return "invalid version: \(value)"
        case .notNewer:
            return "update is not newer than the current version"
        case .requiresNewerMacOS(let value):
            return "update requires macOS \(value)"
        case .invalidURL(let value):
            return "update URL is not an official AgentDot GitHub release URL: \(value)"
        case .invalidSHA256:
            return "update sha256 is invalid"
        case .invalidSignature:
            return "update signature is invalid"
        case .sizeTooLarge(let size):
            return "update zip is too large: \(size) bytes"
        }
    }
}

public struct UpdateManifest: Codable, Equatable {
    public var schema: Int
    public var version: String
    public var minimumMacOS: String
    public var zipURL: URL
    public var dmgURL: URL
    public var releasePage: URL
    public var sha256: String
    public var size: Int
    public var signature: String
    public var publishedAt: String?
    public var notes: String?

    public init(
        schema: Int,
        version: String,
        minimumMacOS: String,
        zipURL: URL,
        dmgURL: URL,
        releasePage: URL,
        sha256: String,
        size: Int,
        signature: String,
        publishedAt: String? = nil,
        notes: String? = nil
    ) {
        self.schema = schema
        self.version = version
        self.minimumMacOS = minimumMacOS
        self.zipURL = zipURL
        self.dmgURL = dmgURL
        self.releasePage = releasePage
        self.sha256 = sha256
        self.size = size
        self.signature = signature
        self.publishedAt = publishedAt
        self.notes = notes
    }

    public func validate(
        currentVersion: SemanticVersion,
        macOSVersion: SemanticVersion
    ) throws {
        guard let newVersion = SemanticVersion(version) else {
            throw UpdateManifestError.invalidVersion(version)
        }
        guard newVersion > currentVersion else {
            throw UpdateManifestError.notNewer
        }
        guard let minimum = SemanticVersion(minimumMacOS) else {
            throw UpdateManifestError.invalidVersion(minimumMacOS)
        }
        guard macOSVersion >= minimum else {
            throw UpdateManifestError.requiresNewerMacOS(minimumMacOS)
        }
        for url in [zipURL, dmgURL, releasePage] {
            guard Self.isOfficialURL(url) else {
                throw UpdateManifestError.invalidURL(url.absoluteString)
            }
        }
        guard sha256.count == 64,
              sha256.allSatisfy(\.isHexDigit) else {
            throw UpdateManifestError.invalidSHA256
        }
        guard !signature.isEmpty,
              Data(base64Encoded: signature) != nil else {
            throw UpdateManifestError.invalidSignature
        }
        guard size > 0, size <= 200 * 1024 * 1024 else {
            throw UpdateManifestError.sizeTooLarge(size)
        }
    }

    private static func isOfficialURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == "github.com"
            && url.path.hasPrefix("/qiuzhaokun/agent-dot/releases/")
    }

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case minimumMacOS = "minimum_macos"
        case zipURL = "zip_url"
        case dmgURL = "dmg_url"
        case releasePage = "release_page"
        case sha256
        case size
        case signature
        case publishedAt = "published_at"
        case notes
    }
}
