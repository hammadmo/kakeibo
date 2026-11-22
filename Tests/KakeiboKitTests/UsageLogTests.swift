import Foundation
import Testing
@testable import KakeiboKit

private func line(id: String = "msg_1", request: String = "req_1", model: String = "claude-opus-5-5",
                  type: String = "assistant", cwd: String = "/Users/me/Projects/Kakeibo",
                  time: String = "2026-11-22T13:37:03.692Z",
                  input: Int = 2, output: Int = 281, write: Int = 27920, write1h: Int = 27920, read: Int = 47061) -> String {
    """
    {"parentUuid":"x","message":{"model":"\(model)","id":"\(id)","type":"message","role":"assistant","content":[{"type":"text","text":"a \\"usage\\":{ inside a string"}],"usage":{"input_tokens":\(input),"cache_creation_input_tokens":\(write),"cache_read_input_tokens":\(read),"output_tokens":\(output),"cache_creation":{"ephemeral_1h_input_tokens":\(write1h),"ephemeral_5m_input_tokens":\(write - write1h)}}},"requestId":"\(request)","type":"\(type)","timestamp":"\(time)","cwd":"\(cwd)","sessionId":"s1"}
    """
}

@Test func parsesAnAssistantReply() throws {
    let record = try #require(UsageLog.parse(line: Data(line().utf8)))
    #expect(record.model == "claude-opus-5-5")
    #expect(record.project == "/Users/me/Projects/Kakeibo")
    #expect(record.input == 2)
    #expect(record.output == 281)
    #expect(record.cacheWrite1h == 27920)
    #expect(record.cacheWrite5m == 0)
    #expect(record.cacheRead == 47061)
    #expect(record.tokens == 2 + 281 + 27920 + 47061)
}

@Test func skipsUserLines() {
    #expect(UsageLog.parse(line: Data(line(type: "user").utf8)) == nil)
    #expect(UsageLog.parse(line: Data(#"{"type":"user","message":{"content":"hi"}}"#.utf8)) == nil)
}

@Test func costUsesThePriceTable() throws {
    // Opus 5.5: $4 in, $20 out, 1h write 2x = $8, read 0.05x = $0.20.
    let record = try #require(UsageLog.parse(line: Data(line(input: 1_000_000, output: 1_000_000, write: 1_000_000,
                                                              write1h: 1_000_000, read: 1_000_000).utf8)))
    #expect(abs(record.cost - (4 + 20 + 8 + 0.2)) < 0.0001)
}

@Test func unknownModelCountsTokensAtNoCost() throws {
    let record = try #require(UsageLog.parse(line: Data(line(model: "claude-future-9").utf8)))
    #expect(record.unknownModel)
    #expect(record.cost == 0)
    #expect(record.tokens > 0)
}

@Test func familyNames() {
    #expect(Pricing.family(of: "claude-fable-5-2") == "Fable")
    #expect(Pricing.family(of: "claude-opus-5-5") == "Opus")
    #expect(Pricing.family(of: "claude-haiku-5-5") == "Haiku")
}

@Test func storeDedupesAndReadsOnlyNewBytes() async throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "kakeibo-test-\(UUID().uuidString)/-Users-me-P")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appending(path: "a.jsonl")
    // The same reply twice, then a half-written line.
    try (line() + "\n" + line() + "\n" + #"{"type":"assist"#).write(to: file, atomically: true, encoding: .utf8)
    let store = UsageStore(root: dir.deletingLastPathComponent())
    #expect(await store.refresh() == 1)

    // Finish the half line with a new reply; only it is read.
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(("ant\"}\n" + line(id: "msg_2") + "\n").utf8))
    try handle.close()
    #expect(await store.refresh() == 1)
    #expect(await store.refresh() == 0)
    #expect(await store.records.count == 2)
}

@Test func timestamps() {
    #expect(Timestamp.parse("2026-11-22T13:37:03.692Z")?.timeIntervalSince1970 == 1_795_354_623.692)
    #expect(Timestamp.parse("2026-11-22T13:37:03Z")?.timeIntervalSince1970 == 1_795_354_623)
    #expect(Timestamp.parse("nonsense") == nil)
}
