import Foundation

/// 从 Claude Code 的本地会话注册表读取用户通过 /rename 设置的名称。
///
/// 注册表位于 `~/.claude/sessions/<pid>.json`，字段包括：
/// `sessionId`、`pid`、`name`、`nameSource`（"user" 表示手动 /rename）、`updatedAt`。
/// 该格式属于 Claude Code 私有元数据，读取失败时由调用方回退到项目文件夹名。
public struct SessionNameResolver {
    public struct Entry: Equatable {
        public let sessionID: String
        public let pid: Int32?
        public let name: String
        public let updatedAt: Double

        public init(sessionID: String, pid: Int32?, name: String, updatedAt: Double) {
            self.sessionID = sessionID
            self.pid = pid
            self.name = name
            self.updatedAt = updatedAt
        }
    }

    public let directory: URL
    public let maxNameLength: Int

    public init(
        directory: URL = SessionNameResolver.defaultDirectory,
        maxNameLength: Int = 64
    ) {
        self.directory = directory
        self.maxNameLength = maxNameLength
    }

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions", isDirectory: true)
    }

    /// 按 sessionId 解析用户命名。同一会话有多条记录时，优先 pid 完全匹配，
    /// 否则取 updatedAt 最新的一条。
    public func resolveNames(for sessions: [SessionState]) -> [String: String] {
        let entries = loadUserEntries()
        guard !entries.isEmpty else { return [:] }
        let grouped = Dictionary(grouping: entries, by: \.sessionID)
        var names: [String: String] = [:]
        for session in sessions {
            guard let candidates = grouped[session.sessionID], !candidates.isEmpty else {
                continue
            }
            let pid = session.terminal.claudePID
            let exact = pid > 0
                ? candidates.first(where: { $0.pid == pid })
                : nil
            if let chosen = exact ?? candidates.max(by: { $0.updatedAt < $1.updatedAt }) {
                names[session.sessionID] = chosen.name
            }
        }
        return names
    }

    /// 读取全部 /rename 名称条目；格式不符或文件损坏时静默跳过。
    public func loadUserEntries() -> [Entry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var entries: [Entry] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let raw = try? JSONDecoder().decode(RawEntry.self, from: data),
                  raw.nameSource == "user",
                  let sessionID = raw.sessionId,
                  !sessionID.isEmpty,
                  let name = normalized(raw.name) else {
                continue
            }
            let filePID = Int32(url.deletingPathExtension().lastPathComponent)
            let rawPID: Int32? = raw.pid.flatMap { Int32(exactly: $0) }
            entries.append(
                Entry(
                    sessionID: sessionID,
                    pid: rawPID ?? filePID,
                    name: name,
                    updatedAt: raw.updatedAt ?? 0
                )
            )
        }
        return entries
    }

    private func normalized(_ name: String?) -> String? {
        guard let name else { return nil }
        let collapsed = name
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count > maxNameLength {
            return String(collapsed.prefix(maxNameLength))
        }
        return collapsed
    }

    private struct RawEntry: Decodable {
        let sessionId: String?
        let pid: Int?
        let name: String?
        let nameSource: String?
        let updatedAt: Double?
    }
}
