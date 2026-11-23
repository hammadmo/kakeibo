import Foundation
import Testing
@testable import KakeiboKit

private let project = "/Users/me/Projects/Kakeibo"

private func json(_ object: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

private func user(_ content: Any, time: String = "2026-11-23T10:00:00.000Z", cwd: String = project, meta: Bool = false) -> Data {
    json(["type": "user", "cwd": cwd, "timestamp": time, "isMeta": meta, "message": ["role": "user", "content": content]])
}

private func edit(_ path: String, time: String = "2026-11-23T10:01:00.000Z") -> Data {
    json(["type": "assistant", "cwd": project, "timestamp": time,
          "message": ["role": "assistant", "content": [["type": "tool_use", "name": "Edit", "input": ["file_path": path]]]]])
}

private let start = Timestamp.parse("2026-11-23T00:00:00Z")!

@Test func digestKeepsOnlyTodaysOwnPromptsAndFiles() {
    let long = String(repeating: "a", count: 500)
    let lines = [
        user("Add a heatmap"),
        user(long),
        user("yesterday's prompt", time: "2026-11-22T10:00:00.000Z"),
        user("other project", cwd: "/elsewhere"),
        user("<command-name>/clear</command-name>"),
        user("meta note", meta: true),
        user([["type": "tool_result", "content": "secret tool output"]]),
        edit(project + "/Sources/App.swift"),
        edit(project + "/Sources/App.swift"),
        edit("/tmp/notes.md"),
    ]
    let digest = Digest.build(lines: lines, project: project, from: start)
    #expect(digest.prompts.count == 2)
    #expect(digest.prompts[0] == "Add a heatmap")
    #expect(digest.prompts[1].count == Digest.promptLength)
    #expect(digest.files == ["Sources/App.swift", "notes.md"])
}

@Test func messageStaysWithinTheBudget() {
    let digest = Digest(prompts: Array(repeating: String(repeating: "p", count: 200), count: 500),
                        files: ["App.swift"], commits: ["abc Add heatmap"])
    let message = digest.message(projectName: "Kakeibo")
    #expect(message.count <= Digest.characterBudget)
    #expect(message.contains("abc Add heatmap"))
    #expect(message.contains("App.swift"))
}

@Test func parsesTheReply() {
    let ok = json(["type": "result", "is_error": false, "result": " Built the Dashboard. Fixed snapshots. ",
                   "usage": ["input_tokens": 2, "output_tokens": 40, "cache_creation_input_tokens": 4000, "cache_read_input_tokens": 100]])
    let parsed = SummaryReply.parse(ok)
    #expect(parsed.reply == SummaryReply(text: "Built the Dashboard. Fixed snapshots.", tokens: 4142))

    let failed = SummaryReply.parse(json(["type": "result", "is_error": true, "result": "Claude usage limit reached.\nTry later."]))
    #expect(failed.reply == nil)
    #expect(failed.error == "Claude usage limit reached.")

    #expect(SummaryReply.parse(Data("Error: not logged in\n".utf8)).error == "Error: not logged in")
    #expect(SummaryReply.parse(Data()).error == nil)
}
