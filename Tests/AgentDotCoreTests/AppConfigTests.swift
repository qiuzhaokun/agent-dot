import Foundation
import AgentDotCore

func runAppConfigTests() {
    runTest("AppConfig defaults to threshold five and launch at login") {
        expectEqual(AppConfig.default.thresholdN, 5)
        expect(AppConfig.default.launchAtLogin)
        expectEqual(AppConfig.default.schema, 1)
    }

    runTest("AppConfig clamps threshold to 1 through 9") {
        var config = AppConfig.default
        config.thresholdN = 0
        expectEqual(config.clamped().thresholdN, 1)
        config.thresholdN = 20
        expectEqual(config.clamped().thresholdN, 9)
    }

    runTest("AppConfig clamps anchor to normalized bounds") {
        var config = AppConfig.default
        config.ballAnchor = BallAnchor(screenID: "1", normalizedX: -0.5, normalizedY: 1.5)
        let anchor = config.clamped().ballAnchor
        expectEqual(anchor?.normalizedX, 0)
        expectEqual(anchor?.normalizedY, 1)
    }

    runTest("AppConfig expandedListHeight defaults to nil") {
        expectNil(AppConfig.default.expandedListHeight)
    }

    runTest("AppConfig clamps expandedListHeight to one through nine rows") {
        var config = AppConfig.default
        config.expandedListHeight = 20
        expectEqual(config.clamped().expandedListHeight, AppConfig.minListHeight)
        config.expandedListHeight = 1000
        expectEqual(config.clamped().expandedListHeight, AppConfig.maxListHeight)
        config.expandedListHeight = 320
        expectEqual(config.clamped().expandedListHeight, 320)
    }

    runTest("AppConfig expandedPanelWidth defaults to nil") {
        expectNil(AppConfig.default.expandedPanelWidth)
    }

    runTest("AppConfig clamps expandedPanelWidth") {
        var config = AppConfig.default
        config.expandedPanelWidth = 100
        expectEqual(config.clamped().expandedPanelWidth, AppConfig.minPanelWidth)
        config.expandedPanelWidth = 1000
        expectEqual(config.clamped().expandedPanelWidth, AppConfig.maxPanelWidth)
        config.expandedPanelWidth = 420
        expectEqual(config.clamped().expandedPanelWidth, 420)
    }

    runTest("AppConfig background opacity defaults to opaque and clamps to 10 through 100") {
        expectEqual(AppConfig.default.ballBackgroundOpacity, 100)
        expectEqual(AppConfig.default.listBackgroundOpacity, 100)

        var config = AppConfig.default
        config.ballBackgroundOpacity = 0
        config.listBackgroundOpacity = 200
        let clamped = config.clamped()
        expectEqual(clamped.ballBackgroundOpacity, AppConfig.minBackgroundOpacity)
        expectEqual(clamped.listBackgroundOpacity, AppConfig.maxBackgroundOpacity)
    }

    runTest("AppConfig decodes missing opacity and sounds with defaults") {
        let data = try JSONEncoder().encode(["thresholdN": 7])
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        expectEqual(config.ballBackgroundOpacity, 100)
        expectEqual(config.listBackgroundOpacity, 100)
        expectEqual(config.authorizationSoundEnabled, false)
        expectEqual(config.completionSoundEnabled, false)
        expectEqual(config.authorizationSoundName, "Glass")
        expectEqual(config.completionSoundName, "Ping")
    }

    runTest("AppConfig sound reminders default to off") {
        expectEqual(AppConfig.default.authorizationSoundEnabled, false)
        expectEqual(AppConfig.default.completionSoundEnabled, false)
    }

    runTest("ConfigStore round trip") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: url)
        var config = AppConfig.default
        config.thresholdN = 7
        config.launchAtLogin = false
        config.expandedListHeight = 384
        config.expandedPanelWidth = 420
        config.ballBackgroundOpacity = 40
        config.listBackgroundOpacity = 60
        config.authorizationSoundEnabled = true
        config.completionSoundEnabled = true
        config.authorizationSoundName = "Hero"
        config.completionSoundName = "Funk"
        try store.save(config)
        expectEqual(store.load().thresholdN, 7)
        expectEqual(store.load().launchAtLogin, false)
        expectEqual(store.load().expandedListHeight, 384)
        expectEqual(store.load().expandedPanelWidth, 420)
        expectEqual(store.load().ballBackgroundOpacity, 40)
        expectEqual(store.load().listBackgroundOpacity, 60)
        expectEqual(store.load().authorizationSoundEnabled, true)
        expectEqual(store.load().completionSoundEnabled, true)
        expectEqual(store.load().authorizationSoundName, "Hero")
        expectEqual(store.load().completionSoundName, "Funk")
    }

    runTest("ConfigStore update merges into latest on-disk config") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: url)
        var config = AppConfig.default
        config.skippedUpdateVersion = "9.9.9"
        config.lastUpdateCheckAt = 1_700_000_000
        try store.save(config)

        let merged = store.update { $0.expandedPanelWidth = 420 }
        expectEqual(merged.expandedPanelWidth, 420)
        expectEqual(merged.skippedUpdateVersion, "9.9.9")
        expectEqual(merged.lastUpdateCheckAt, 1_700_000_000)

        let loaded = store.load()
        expectEqual(loaded.expandedPanelWidth, 420)
        expectEqual(loaded.skippedUpdateVersion, "9.9.9")
        expectEqual(loaded.lastUpdateCheckAt, 1_700_000_000)
    }

    runTest("ConfigStore concurrent updates keep every field") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: url)
        try store.save(.default)

        DispatchQueue.concurrentPerform(iterations: 8) { index in
            store.update { config in
                switch index {
                case 0: config.thresholdN = 7
                case 1: config.expandedListHeight = 384
                case 2: config.expandedPanelWidth = 420
                case 3: config.ballBackgroundOpacity = 40
                case 4: config.listBackgroundOpacity = 60
                case 5: config.authorizationSoundEnabled = true
                case 6: config.skippedUpdateVersion = "9.9.9"
                default: config.lastUpdateCheckAt = 1_700_000_000
                }
            }
        }

        let loaded = store.load()
        expectEqual(loaded.thresholdN, 7)
        expectEqual(loaded.expandedListHeight, 384)
        expectEqual(loaded.expandedPanelWidth, 420)
        expectEqual(loaded.ballBackgroundOpacity, 40)
        expectEqual(loaded.listBackgroundOpacity, 60)
        expectEqual(loaded.authorizationSoundEnabled, true)
        expectEqual(loaded.skippedUpdateVersion, "9.9.9")
        expectEqual(loaded.lastUpdateCheckAt, 1_700_000_000)
    }

    runTest("ConfigStore returns defaults on corrupt file") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        try "{not json".write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigStore(fileURL: url)
        expectEqual(store.load().thresholdN, 5)
    }
}
