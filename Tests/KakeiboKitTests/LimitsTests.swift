import Foundation
import Testing
@testable import KakeiboKit

@Test func decodesTheThreeLimits() throws {
    let json = """
    {"five_hour":{"utilization":42.0,"resets_at":"2026-11-22T18:00:00.000+00:00"},
     "seven_day":{"utilization":18,"resets_at":"2026-11-24T09:00:00+00:00"},
     "seven_day_fable":{"utilization":63.5,"resets_at":null},
     "extra_usage":{"is_enabled":false}}
    """
    let limits = try Limits.decode(Data(json.utf8))
    #expect(limits.session?.used == 42)
    #expect(limits.session?.resets != nil)
    #expect(limits.weekly?.used == 18)
    #expect(limits.fable?.used == 63.5)
    #expect(limits.fable?.resets == nil)
    #expect(limits.keys == ["five_hour", "seven_day", "seven_day_fable"])
}

@Test func missingFableIsHiddenNotZero() throws {
    let limits = try Limits.decode(Data(#"{"five_hour":{"utilization":5},"seven_day":{"utilization":1}}"#.utf8))
    #expect(limits.fable == nil)
}

@Test func resetText() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(ResetText.short(now.addingTimeInterval(2 * 3600 + 14 * 60 + 30), now: now) == "Resets in 2 h 14 m")
    #expect(ResetText.short(now.addingTimeInterval(38 * 60), now: now) == "Resets in 38 m")
    #expect(ResetText.spoken(now.addingTimeInterval(2 * 3600 + 14 * 60), now: now) == "resets in 2 hours 14 minutes")
}
