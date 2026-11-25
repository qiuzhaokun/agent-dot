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

    runTest("ConfigStore round trip") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: url)
        var config = AppConfig.default
        config.thresholdN = 7
        config.launchAtLogin = false
        try store.save(config)
        expectEqual(store.load().thresholdN, 7)
        expectEqual(store.load().launchAtLogin, false)
    }

    runTest("ConfigStore returns defaults on corrupt file") {
        let url = TestSupport.tempDirectory().appendingPathComponent("config.json")
        try "{not json".write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigStore(fileURL: url)
        expectEqual(store.load().thresholdN, 5)
    }
}
