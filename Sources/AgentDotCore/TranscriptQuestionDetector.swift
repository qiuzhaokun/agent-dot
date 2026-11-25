import Foundation

/// 判断 Claude Code transcript 里最后一条 assistant 文本是否在向用户提问。
/// 只在 Stop hook 时调用，读取文件尾部，避免扫描整个大文件。
public enum TranscriptQuestionDetector {
    public static func lastAssistantTextEndsWithQuestion(
        transcriptPath: String,
        maxBytes: Int = 262_144
    ) -> Bool {
        guard let text = lastAssistantText(
            transcriptPath: transcriptPath,
            maxBytes: maxBytes
        ) else {
            return false
        }
        return isQuestion(text)
    }

    public static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lines = trimmed.components(separatedBy: .newlines)
        let lastLine = lines.reversed()
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        if lastLine.hasSuffix("?") || lastLine.hasSuffix("？") {
            return true
        }
        let phrases = [
            "请确认",
            "需要你确认",
            "是否需要",
            "是否继续",
            "要不要我",
            "可以吗",
            "你希望我"
        ]
        return phrases.contains { lastLine.contains($0) }
    }

    private static func lastAssistantText(
        transcriptPath: String,
        maxBytes: Int
    ) -> String? {
        guard maxBytes > 0,
              let handle = FileHandle(forReadingAtPath: transcriptPath) else {
            return nil
        }
        defer { try? handle.close() }

        do {
            let size = try handle.seekToEnd()
            let offset = size > UInt64(maxBytes)
                ? size - UInt64(maxBytes)
                : 0
            try handle.seek(toOffset: offset)
            guard let data = try handle.readToEnd(),
                  let content = String(data: data, encoding: .utf8) else {
                return nil
            }

            for line in content
                .split(separator: "\n", omittingEmptySubsequences: true)
                .reversed() {
                guard let lineData = String(line).data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: lineData),
                      let entry = object as? [String: Any],
                      entry["type"] as? String == "assistant",
                      let message = entry["message"] as? [String: Any],
                      let blocks = message["content"] as? [[String: Any]] else {
                    continue
                }
                let text = blocks.compactMap { block -> String? in
                    guard block["type"] as? String == "text" else { return nil }
                    return block["text"] as? String
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
