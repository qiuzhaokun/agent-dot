import Foundation
import Darwin

public enum SessionFileStoreError: Error, CustomStringConvertible {
    case invalidSessionID
    case cannotOpenLockFile(String)

    public var description: String {
        switch self {
        case .invalidSessionID:
            return "invalid session id"
        case .cannotOpenLockFile(let path):
            return "cannot open lock file: \(path)"
        }
    }
}

public struct SessionFileStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func fileURL(sessionID: String) -> URL {
        directory
            .appendingPathComponent(sessionID)
            .appendingPathExtension("json")
    }

    public static func isValidSessionID(_ value: String) -> Bool {
        let bytes = value.utf8
        guard (1...128).contains(bytes.count) else { return false }
        return bytes.allSatisfy { byte in
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
                || byte == 95
                || byte == 45
        }
    }

    public func load(sessionID: String) -> SessionState? {
        guard Self.isValidSessionID(sessionID) else { return nil }
        guard let data = try? Data(contentsOf: fileURL(sessionID: sessionID)) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionState.self, from: data)
    }

    public func loadAll() -> [SessionState] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(SessionState.self, from: data)
        }
    }

    public func save(_ state: SessionState) throws {
        guard Self.isValidSessionID(state.sessionID) else {
            throw SessionFileStoreError.invalidSessionID
        }
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let url = fileURL(sessionID: state.sessionID)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    public func withSessionLock<T>(
        sessionID: String,
        _ body: () throws -> T
    ) throws -> T {
        guard Self.isValidSessionID(sessionID) else {
            throw SessionFileStoreError.invalidSessionID
        }
        try ensureDirectory()
        let lockURL = directory
            .appendingPathComponent(sessionID)
            .appendingPathExtension("lock")
        let fd = lockURL.path.withCString { path in
            open(path, O_CREAT | O_RDWR, 0o600)
        }
        guard fd >= 0 else {
            throw SessionFileStoreError.cannotOpenLockFile(lockURL.path)
        }
        defer {
            _ = flock(fd, LOCK_UN)
            close(fd)
        }
        while flock(fd, LOCK_EX) != 0 {
            if errno != EINTR {
                throw SessionFileStoreError.cannotOpenLockFile(lockURL.path)
            }
        }
        return try body()
    }

    public func removeOrphanLocks() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for url in urls where url.pathExtension == "lock" {
            let jsonURL = url.deletingPathExtension().appendingPathExtension("json")
            if !FileManager.default.fileExists(atPath: jsonURL.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public func removeOlderThan(_ timestamp: Int64) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let state = try? JSONDecoder().decode(SessionState.self, from: data) else {
                continue
            }
            if state.updatedAt < timestamp {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}
