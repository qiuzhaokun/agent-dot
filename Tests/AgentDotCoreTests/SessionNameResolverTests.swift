import Foundation
import AgentDotCore

private func writeRegistryEntry(
    directory: URL,
    filePID: Int32,
    pid: Int32?,
    sessionID: String,
    name: String,
    source: String = "user",
    updatedAt: Double = 100
) throws {
    var payload: [String: Any] = [
        "sessionId": sessionID,
        "name": name,
        "nameSource": source,
        "updatedAt": updatedAt
    ]
    if let pid {
        payload["pid"] = Int(pid)
    }
    let data = try JSONSerialization.data(withJSONObject: payload)
    try data.write(to: directory.appendingPathComponent("\(filePID).json"))
}

private func makeSession(id: String, pid: Int32) -> SessionState {
    var session = TestSupport.makeSession(claudePID: pid)
    session.sessionID = id
    return session
}

func runSessionNameResolverTests() {
    runTest("SessionNameResolver only accepts user rename names") {
        let directory = TestSupport.tempDirectory()
        try writeRegistryEntry(
            directory: directory,
            filePID: 101,
            pid: 101,
            sessionID: "s1",
            name: "重构登录"
        )
        try writeRegistryEntry(
            directory: directory,
            filePID: 102,
            pid: 102,
            sessionID: "s2",
            name: "自动名",
            source: "derived"
        )
        try writeRegistryEntry(
            directory: directory,
            filePID: 103,
            pid: 103,
            sessionID: "s3",
            name: "其他会话命名",
            source: "peer"
        )

        let resolver = SessionNameResolver(directory: directory)
        let names = resolver.resolveNames(for: [
            makeSession(id: "s1", pid: 101),
            makeSession(id: "s2", pid: 102),
            makeSession(id: "s3", pid: 103)
        ])

        expectEqual(names["s1"], "重构登录")
        expectNil(names["s2"])
        expectNil(names["s3"])
    }

    runTest("SessionNameResolver prefers exact pid match") {
        let directory = TestSupport.tempDirectory()
        try writeRegistryEntry(
            directory: directory,
            filePID: 200,
            pid: 200,
            sessionID: "s1",
            name: "旧名",
            updatedAt: 100
        )
        try writeRegistryEntry(
            directory: directory,
            filePID: 201,
            pid: 201,
            sessionID: "s1",
            name: "新名",
            updatedAt: 300
        )

        let resolver = SessionNameResolver(directory: directory)
        let names = resolver.resolveNames(for: [makeSession(id: "s1", pid: 200)])
        expectEqual(names["s1"], "旧名")
    }

    runTest("SessionNameResolver falls back to newest entry when pid differs") {
        let directory = TestSupport.tempDirectory()
        try writeRegistryEntry(
            directory: directory,
            filePID: 300,
            pid: 300,
            sessionID: "s1",
            name: "旧名",
            updatedAt: 100
        )
        try writeRegistryEntry(
            directory: directory,
            filePID: 301,
            pid: 301,
            sessionID: "s1",
            name: "新名",
            updatedAt: 300
        )

        let resolver = SessionNameResolver(directory: directory)
        let names = resolver.resolveNames(for: [makeSession(id: "s1", pid: 999)])
        expectEqual(names["s1"], "新名")
    }

    runTest("SessionNameResolver uses file pid when pid field is missing") {
        let directory = TestSupport.tempDirectory()
        try writeRegistryEntry(
            directory: directory,
            filePID: 404,
            pid: nil,
            sessionID: "s1",
            name: "文件 PID"
        )

        let resolver = SessionNameResolver(directory: directory)
        let names = resolver.resolveNames(for: [makeSession(id: "s1", pid: 404)])
        expectEqual(names["s1"], "文件 PID")
    }

    runTest("SessionNameResolver normalizes whitespace and caps name length") {
        let directory = TestSupport.tempDirectory()
        try writeRegistryEntry(
            directory: directory,
            filePID: 500,
            pid: 500,
            sessionID: "s1",
            name: "  第一行\n\t第二行  "
        )
        let longName = String(repeating: "名", count: 80)
        try writeRegistryEntry(
            directory: directory,
            filePID: 501,
            pid: 501,
            sessionID: "s2",
            name: longName
        )

        let resolver = SessionNameResolver(directory: directory, maxNameLength: 64)
        let names = resolver.resolveNames(for: [
            makeSession(id: "s1", pid: 500),
            makeSession(id: "s2", pid: 501)
        ])

        expectEqual(names["s1"], "第一行 第二行")
        expectEqual(names["s2"]?.count, 64)
    }

    runTest("SessionNameResolver ignores malformed files and missing directory") {
        let directory = TestSupport.tempDirectory()
        try "{not json".write(
            to: directory.appendingPathComponent("600.json"),
            atomically: true,
            encoding: .utf8
        )

        let resolver = SessionNameResolver(directory: directory)
        let sessions = [makeSession(id: "s1", pid: 600)]
        expect(resolver.resolveNames(for: sessions).isEmpty)

        let missing = SessionNameResolver(
            directory: directory.appendingPathComponent("missing", isDirectory: true)
        )
        expect(missing.resolveNames(for: sessions).isEmpty)
    }
}
