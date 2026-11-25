import Foundation
import CryptoKit
import AgentDotCore

private func makeFakeApp(at url: URL, version: String) throws {
    let contents = url.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(
        at: contents,
        withIntermediateDirectories: true
    )
    let info: [String: Any] = [
        "CFBundleIdentifier": "dev.agentdot.app",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: info,
        format: .xml,
        options: 0
    )
    try data.write(to: contents.appendingPathComponent("Info.plist"))
}

private func updateManifest(
    version: String = "0.1.1",
    zipURL: String = "https://github.com/qiuzhaokun/agent-dot/releases/download/v0.1.1/AgentDot-0.1.1.zip",
    size: Int = 1_000
) -> UpdateManifest {
    UpdateManifest(
        schema: 1,
        version: version,
        minimumMacOS: "13.0",
        zipURL: URL(string: zipURL)!,
        dmgURL: URL(string: "https://github.com/qiuzhaokun/agent-dot/releases/download/v0.1.1/AgentDot-0.1.1.dmg")!,
        releasePage: URL(string: "https://github.com/qiuzhaokun/agent-dot/releases/tag/v0.1.1")!,
        sha256: String(repeating: "a", count: 64),
        size: size,
        signature: Data(repeating: 1, count: 64).base64EncodedString(),
        publishedAt: "2026-11-25T08:00:00Z",
        notes: "test"
    )
}

func runUpdateTests() {
    runTest("SemanticVersion compares numeric components") {
        expect(SemanticVersion("0.1.10")! > SemanticVersion("0.1.9")!)
        expect(SemanticVersion("1.0.0")! > SemanticVersion("0.9.9")!)
        expectEqual(SemanticVersion("0.1")!, SemanticVersion("0.1.0")!)
        expectNil(SemanticVersion("abc"))
        expectNil(SemanticVersion("1.2.3.4"))
    }

    runTest("UpdateManifest validates happy path") {
        let manifest = updateManifest()
        try manifest.validate(
            currentVersion: SemanticVersion("0.1.0")!,
            macOSVersion: SemanticVersion("13.0")!
        )
    }

    runTest("UpdateManifest rejects downgrade, bad host and oversized zip") {
        expectThrows {
            try updateManifest(version: "0.1.0").validate(
                currentVersion: SemanticVersion("0.1.0")!,
                macOSVersion: SemanticVersion("13.0")!
            )
        }
        expectThrows {
            try updateManifest(zipURL: "https://evil.example.com/AgentDot.zip").validate(
                currentVersion: SemanticVersion("0.1.0")!,
                macOSVersion: SemanticVersion("13.0")!
            )
        }
        expectThrows {
            try updateManifest(size: 201 * 1024 * 1024).validate(
                currentVersion: SemanticVersion("0.1.0")!,
                macOSVersion: SemanticVersion("13.0")!
            )
        }
    }

    runTest("UpdateManifest rejects newer minimum macOS") {
        var manifest = updateManifest()
        manifest.minimumMacOS = "28.0"
        expectThrows {
            try manifest.validate(
                currentVersion: SemanticVersion("0.1.0")!,
                macOSVersion: SemanticVersion("27.2")!
            )
        }
    }

    runTest("UpdateSignature verifies and rejects tampering") {
        let key = Curve25519.Signing.PrivateKey()
        let data = Data("agentdot-update".utf8)
        let signature = try key.signature(for: data).base64EncodedString()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()

        expect(UpdateSignature.verify(
            fileData: data,
            signatureBase64: signature,
            publicKeyBase64: publicKey
        ))
        expect(!UpdateSignature.verify(
            fileData: Data("tampered".utf8),
            signatureBase64: signature,
            publicKeyBase64: publicKey
        ))
        expect(!UpdateSignature.verify(
            fileData: data,
            signatureBase64: signature,
            publicKeyBase64: Data(repeating: 0, count: 32).base64EncodedString()
        ))
    }

    runTest("UpdaterEngine replaces app and keeps a backup") {
        let root = TestSupport.tempDirectory()
        let current = root.appendingPathComponent("Applications/AgentDot.app")
        let update = root.appendingPathComponent("Update/AgentDot.app")
        let backups = root.appendingPathComponent("Backups")
        try makeFakeApp(at: current, version: "0.1.0")
        try makeFakeApp(at: update, version: "0.1.1")

        try UpdaterEngine().install(
            currentApp: current,
            newApp: update,
            expectedVersion: "0.1.1",
            backupDirectory: backups
        )

        let installedInfo = try unwrap(
            NSDictionary(contentsOf: current.appendingPathComponent("Contents/Info.plist"))
        )
        expectEqual(installedInfo["CFBundleShortVersionString"] as? String, "0.1.1")
        let backupItems = try FileManager.default.contentsOfDirectory(
            at: backups,
            includingPropertiesForKeys: nil
        )
        expectEqual(backupItems.count, 1)
        expect(!FileManager.default.fileExists(atPath: update.path))
    }

    runTest("UpdaterEngine rejects wrong version without touching current") {
        let root = TestSupport.tempDirectory()
        let current = root.appendingPathComponent("Applications/AgentDot.app")
        let update = root.appendingPathComponent("Update/AgentDot.app")
        let backups = root.appendingPathComponent("Backups")
        try makeFakeApp(at: current, version: "0.1.0")
        try makeFakeApp(at: update, version: "0.1.1")

        expectThrows {
            try UpdaterEngine().install(
                currentApp: current,
                newApp: update,
                expectedVersion: "9.9.9",
                backupDirectory: backups
            )
        }

        let installedInfo = try unwrap(
            NSDictionary(contentsOf: current.appendingPathComponent("Contents/Info.plist"))
        )
        expectEqual(installedInfo["CFBundleShortVersionString"] as? String, "0.1.0")
        expect(FileManager.default.fileExists(atPath: update.path))
    }

    runTest("AppConfig decodes old config with update defaults") {
        let json = #"{"schema":1,"thresholdN":7,"launchAtLogin":false,"ballAnchor":null}"#
        let config = try JSONDecoder().decode(
            AppConfig.self,
            from: Data(json.utf8)
        )
        expectEqual(config.thresholdN, 7)
        expectEqual(config.launchAtLogin, false)
        expect(config.automaticUpdateChecks)
        expectNil(config.skippedUpdateVersion)
        expectNil(config.lastUpdateCheckAt)
        expectNil(config.lastLaunchedVersion)
    }
}
