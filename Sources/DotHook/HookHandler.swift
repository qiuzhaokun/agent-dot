import Foundation
import Darwin
import AgentDotCore

struct HookHandler {
    let store: SessionFileStore
    let resolver: TerminalContextResolver

    @discardableResult
    func handle(input: Data, now: Int64) -> Int32 {
        guard let payload = try? JSONDecoder().decode(HookPayload.self, from: input) else {
            log("malformed hook payload")
            return 0
        }

        do {
            try store.withSessionLock(sessionID: payload.sessionID) {
                let existing = store.load(sessionID: payload.sessionID)
                let terminal: TerminalContext
                if shouldResolveTerminal(
                    existing: existing,
                    event: payload.hookEventName
                ) {
                    terminal = resolver.resolve()
                } else {
                    terminal = existing!.terminal
                }

                if let state = StateReducer().apply(
                    payload: payload,
                    existing: existing,
                    terminal: terminal,
                    now: now
                ) {
                    let isQuestion = payload.hookEventName == "Stop"
                        && (payload.transcriptPath.map {
                            TranscriptQuestionDetector.lastAssistantTextEndsWithQuestion(
                                transcriptPath: $0
                            )
                        } ?? false)
                    try store.save(
                        state.applyingPlainQuestionAttention(
                            now: now,
                            isQuestion: isQuestion
                        )
                    )
                }
            }
        } catch {
            log("hook failed for \(payload.hookEventName): \(error)")
        }
        return 0
    }

    private func shouldResolveTerminal(
        existing: SessionState?,
        event: String
    ) -> Bool {
        if event == "SessionStart" || existing == nil {
            return true
        }
        guard let pid = existing?.terminal.claudePID, pid > 0 else {
            return false
        }
        if kill(pid, 0) == 0 {
            return false
        }
        return errno != EPERM
    }

    private func log(_ message: String) {
        let url = AgentDotPaths.hookLogURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int,
           size > 1_000_000 {
            let rotated = url.appendingPathExtension("1")
            try? FileManager.default.removeItem(at: rotated)
            try? FileManager.default.moveItem(at: url, to: rotated)
        }
        let stamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "[\(stamp)] \(message)\n".data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
