import Foundation
import AgentDotCore

private func assistantEntry(_ text: String) -> [String: Any] {
    [
        "type": "assistant",
        "message": [
            "role": "assistant",
            "content": [
                ["type": "text", "text": text]
            ]
        ]
    ]
}

private func assistantToolUseEntry() -> [String: Any] {
    [
        "type": "assistant",
        "message": [
            "role": "assistant",
            "content": [
                [
                    "type": "tool_use",
                    "id": "toolu_1",
                    "name": "Bash",
                    "input": ["command": "ls"]
                ]
            ]
        ]
    ]
}

private func userEntry(_ text: String) -> [String: Any] {
    [
        "type": "user",
        "message": [
            "role": "user",
            "content": [
                ["type": "text", "text": text]
            ]
        ]
    ]
}

private func writeTranscript(_ entries: [[String: Any]]) -> String {
    let directory = TestSupport.tempDirectory()
    let url = directory.appendingPathComponent("transcript.jsonl")
    let lines = entries.compactMap { entry -> String? in
        guard let data = try? JSONSerialization.data(withJSONObject: entry) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    try? (lines.joined(separator: "\n") + "\n").write(
        to: url,
        atomically: true,
        encoding: .utf8
    )
    return url.path
}

func runTranscriptQuestionDetectorTests() {
    runTest("TranscriptQuestionDetector recognizes question endings") {
        expect(TranscriptQuestionDetector.isQuestion("要我现在执行吗？"))
        expect(TranscriptQuestionDetector.isQuestion("需要我继续吗?"))
        expect(TranscriptQuestionDetector.isQuestion("请确认后我再继续"))
        expect(TranscriptQuestionDetector.isQuestion("这里有两个方案，你希望我怎么处理"))
        expect(!TranscriptQuestionDetector.isQuestion("已完成，代码已提交。"))
        expect(!TranscriptQuestionDetector.isQuestion("明天再说"))
    }

    runTest("TranscriptQuestionDetector ignores question inside code block") {
        let text = "执行结果如下：\n\n```\necho \"你好?\"\n```"
        expect(!TranscriptQuestionDetector.isQuestion(text))
    }

    runTest("TranscriptQuestionDetector reads the last assistant text") {
        let path = writeTranscript([
            assistantEntry("我会先检查一下。"),
            assistantToolUseEntry(),
            userEntry("检查完了吗？"),
            assistantEntry("检查完成，需要我继续修复吗？")
        ])
        expect(
            TranscriptQuestionDetector.lastAssistantTextEndsWithQuestion(
                transcriptPath: path
            )
        )
    }

    runTest("TranscriptQuestionDetector skips trailing tool use messages") {
        let path = writeTranscript([
            assistantEntry("是否需要我继续？"),
            assistantToolUseEntry()
        ])
        expect(
            TranscriptQuestionDetector.lastAssistantTextEndsWithQuestion(
                transcriptPath: path
            )
        )
    }

    runTest("TranscriptQuestionDetector ignores non-question last reply") {
        let path = writeTranscript([
            assistantEntry("是否需要我继续？"),
            assistantEntry("已经处理完成。")
        ])
        expect(
            !TranscriptQuestionDetector.lastAssistantTextEndsWithQuestion(
                transcriptPath: path
            )
        )
    }

    runTest("TranscriptQuestionDetector handles missing file") {
        expect(
            !TranscriptQuestionDetector.lastAssistantTextEndsWithQuestion(
                transcriptPath: "/tmp/agentdot-missing-\(UUID().uuidString).jsonl"
            )
        )
    }
}
