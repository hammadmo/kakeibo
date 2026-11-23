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

@Test func readsTheLimitsArray() throws {
    // The live shape on 2026-11-23 (values changed).
    let json = """
    {"five_hour":{"utilization":11.0,"resets_at":"2026-11-23T04:20:00.814358+00:00"},
     "seven_day":{"utilization":57.0,"resets_at":"2026-11-27T06:00:00.814377+00:00"},
     "seven_day_opus":null,"seven_day_sonnet":null,
     "limits":[
      {"group":"session","kind":"session","percent":12,"resets_at":"2026-11-23T04:20:00.814358+00:00","scope":null},
      {"group":"weekly","kind":"weekly_all","percent":57,"resets_at":"2026-11-27T06:00:00.814377+00:00","scope":null},
      {"group":"weekly","kind":"weekly_scoped","percent":69,"resets_at":"2026-11-27T05:59:59.814510+00:00",
       "scope":{"model":{"display_name":"Fable","id":null},"surface":null}}]}
    """
    let limits = try Limits.decode(Data(json.utf8))
    #expect(limits.session?.used == 12)
    #expect(limits.weekly?.used == 57)
    #expect(limits.fable?.used == 69)
    #expect(limits.fable?.resets != nil)
}

@Test func decodesTheWeeklyBreakdown() throws {
    let json = """
    {"seven_day_breakdown":{"as_of":"2026-11-22T23:46:06.837241+00:00","rows":[
      {"display_name":"Claude Code","key":"claude_code","percent":93,"percent_of_limit":53},
      {"display_name":"Chats","key":"chat","percent":1,"percent_of_limit":1},
      {"display_name":"Cowork","key":"cowork","percent":6,"percent_of_limit":3},
      {"display_name":"Other","key":"other","percent":0,"percent_of_limit":0}],
      "window_started_at":"2026-11-20T06:00:00.814377+00:00"}}
    """
    let breakdown = try #require(try Limits.decode(Data(json.utf8)).breakdown)
    #expect(breakdown.rows.map(\.name) == ["Claude Code", "Chats", "Cowork", "Other"])
    #expect(breakdown.rows[0].shareOfUse == 93)
    #expect(breakdown.rows[0].shareOfLimit == 53)
    #expect(breakdown.rows[3].shareOfLimit == 0)
    #expect(breakdown.asOf != nil && breakdown.weekStarted != nil)
}

@Test func noBreakdownMeansHidden() throws {
    #expect(try Limits.decode(Data(#"{"seven_day_breakdown":null}"#.utf8)).breakdown == nil)
    #expect(try Limits.decode(Data(#"{"seven_day_breakdown":{"rows":[]}}"#.utf8)).breakdown == nil)
}
