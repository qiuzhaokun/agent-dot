import Foundation
import AgentDotCore

func runUIStateStoreTests() {
    runTest("UIStateStore acknowledge persists and clears") {
        let url = TestSupport.tempDirectory().appendingPathComponent("ui-state.json")
        let store = UIStateStore(fileURL: url)
        store.acknowledge(sessionID: "abc123", at: 100, waitingSince: 90)
        expectEqual(store.load().sessions["abc123"]?.acknowledgedAt, 100)
        expectEqual(store.load().sessions["abc123"]?.waitingSinceAtAck, 90)

        let reloaded = UIStateStore(fileURL: url)
        expectEqual(reloaded.load().sessions["abc123"]?.acknowledgedAt, 100)
        expectEqual(reloaded.load().sessions["abc123"]?.waitingSinceAtAck, 90)

        reloaded.clearAcknowledgment(sessionID: "abc123")
        expectNil(reloaded.load().sessions["abc123"]?.acknowledgedAt)
        expectNil(reloaded.load().sessions["abc123"]?.waitingSinceAtAck)
    }

    runTest("UIStateStore prune removes missing sessions") {
        let url = TestSupport.tempDirectory().appendingPathComponent("ui-state.json")
        let store = UIStateStore(fileURL: url)
        store.acknowledge(sessionID: "keep", at: 100, waitingSince: 90)
        store.acknowledge(sessionID: "drop", at: 100, waitingSince: 90)
        store.prune(existingSessionIDs: ["keep"])
        let state = store.load()
        expectNotNil(state.sessions["keep"])
        expectNil(state.sessions["drop"])
    }

    runTest("UIStateStore returns empty state for corrupt file") {
        let url = TestSupport.tempDirectory().appendingPathComponent("ui-state.json")
        try "{not json".write(to: url, atomically: true, encoding: .utf8)
        let store = UIStateStore(fileURL: url)
        expectEqual(store.load().sessions.count, 0)
    }
}
