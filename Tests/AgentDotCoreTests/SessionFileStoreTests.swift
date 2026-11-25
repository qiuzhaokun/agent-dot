import Foundation
import AgentDotCore

func runSessionFileStoreTests() {
    runTest("SessionFileStore save/load round trip") {
        let store = SessionFileStore(directory: TestSupport.tempDirectory())
        let state = TestSupport.makeSession()
        try store.save(state)
        expectEqual(store.load(sessionID: state.sessionID), state)
    }

    runTest("SessionFileStore ignores corrupt JSON") {
        let directory = TestSupport.tempDirectory()
        let store = SessionFileStore(directory: directory)
        try "{not json".write(
            to: store.fileURL(sessionID: "abc"),
            atomically: true,
            encoding: .utf8
        )
        expectNil(store.load(sessionID: "abc"))
        expectEqual(store.loadAll().count, 0)
    }

    runTest("SessionFileStore loadAll skips lock and temp files") {
        let directory = TestSupport.tempDirectory()
        let store = SessionFileStore(directory: directory)
        try store.save(TestSupport.makeSession())
        try "".write(
            to: directory.appendingPathComponent("abc123.lock"),
            atomically: true,
            encoding: .utf8
        )
        try "".write(
            to: directory.appendingPathComponent("abc123.json.tmp"),
            atomically: true,
            encoding: .utf8
        )
        expectEqual(store.loadAll().count, 1)
    }

    runTest("SessionFileStore lock serializes concurrent increments") {
        let directory = TestSupport.tempDirectory()
        let store = SessionFileStore(directory: directory)
        let counter = directory.appendingPathComponent("counter")
        try "0".write(to: counter, atomically: true, encoding: .utf8)

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            try? store.withSessionLock(sessionID: "abc123") {
                let value = Int(try String(contentsOf: counter, encoding: .utf8)) ?? 0
                try "\(value + 1)".write(to: counter, atomically: true, encoding: .utf8)
            }
        }

        expectEqual(try String(contentsOf: counter, encoding: .utf8), "50")
    }

    runTest("SessionFileStore removeOlderThan") {
        let directory = TestSupport.tempDirectory()
        let store = SessionFileStore(directory: directory)
        var old = TestSupport.makeSession()
        old.updatedAt = 100
        try store.save(old)
        store.removeOlderThan(200)
        expectNil(store.load(sessionID: old.sessionID))
    }

    runTest("SessionFileStore removes orphan lock files") {
        let directory = TestSupport.tempDirectory()
        let store = SessionFileStore(directory: directory)
        try store.save(TestSupport.makeSession())
        let liveLock = directory.appendingPathComponent("abc123.lock")
        let orphanLock = directory.appendingPathComponent("orphan.lock")
        try "".write(to: liveLock, atomically: true, encoding: .utf8)
        try "".write(to: orphanLock, atomically: true, encoding: .utf8)

        store.removeOrphanLocks()

        expect(FileManager.default.fileExists(atPath: liveLock.path))
        expect(!FileManager.default.fileExists(atPath: orphanLock.path))
    }

    runTest("SessionFileStore rejects invalid session id") {
        let store = SessionFileStore(directory: TestSupport.tempDirectory())
        let state = TestSupport.makeSession()
        expectThrows {
            try store.save(
                SessionState(
                    schema: state.schema,
                    sessionID: "../escape",
                    cwd: state.cwd,
                    projectName: state.projectName,
                    state: state.state,
                    startedAt: state.startedAt,
                    updatedAt: state.updatedAt,
                    lastActivityAt: state.lastActivityAt,
                    terminal: state.terminal
                )
            )
        }
        expectNil(store.load(sessionID: "../escape"))
    }
}
