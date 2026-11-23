import Foundation
import Testing
@testable import KakeiboKit

private let project = "/Users/me/Projects/Kakeibo"
private func line(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) }
private func user(_ text: String, _ time: String, session: String = "s1", branch: String = "main") -> Data {
    line(["type": "user", "cwd": project, "sessionId": session, "gitBranch": branch, "timestamp": time,
          "message": ["role": "user", "content": text]])
}
private func edit(_ file: String, _ time: String, session: String = "s1") -> Data {
    line(["type": "assistant", "cwd": project, "sessionId": session, "timestamp": time,
          "message": ["content": [["type": "tool_use", "name": "Edit", "input": ["file_path": project + "/" + file]]]]])
}

@Test func sessionsBecomeTimelineEntries() {
    let start = Timestamp.parse("2026-11-23T00:00:00Z")!
    let lines = [
        user("Add the heatmap to the Dashboard and make it gold " + String(repeating: "x", count: 200), "2026-11-23T09:12:00Z"),
        edit("Sources/A.swift", "2026-11-23T09:20:00Z"),
        user("<command-name>/clear</command-name>", "2026-11-23T09:30:00Z"),
        user("Now fix the snapshots", "2026-11-23T10:00:00Z"),
        edit("Sources/A.swift", "2026-11-23T10:10:00Z"),
        edit("Sources/B.swift", "2026-11-23T10:40:00Z"),
        user("Second session", "2026-11-23T12:00:00Z", session: "s2", branch: "HEAD"),
        user("Yesterday", "2026-11-22T12:00:00Z", session: "s0"),
    ]
    let sessions = Timeline.build(lines: lines, project: project, from: start)
    #expect(sessions.map(\.id) == ["s1", "s2"])
    let first = sessions[0]
    #expect(first.start == Timestamp.parse("2026-11-23T09:12:00Z"))
    #expect(first.end == Timestamp.parse("2026-11-23T10:40:00Z"))
    #expect(first.branch == "main")
    #expect(first.prompts == 2)
    #expect(first.firstPrompt?.count == Timeline.promptLength)
    #expect(first.files == ["Sources/A.swift", "Sources/B.swift"])
    #expect(sessions[1].branch == nil) // detached HEAD shows no branch
}

@Test func liveMeansARecentLine() {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = TimelineSession(id: "s", start: now, end: now.addingTimeInterval(-240), branch: nil,
                                  firstPrompt: nil, prompts: 0, files: [])
    #expect(session.isLive(now: now))
    #expect(!session.isLive(now: now.addingTimeInterval(120)))
}
