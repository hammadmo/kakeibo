import Foundation
import Testing
@testable import KakeiboKit

@Test func weekStartsOnTheLocalesFirstWeekday() {
    var monday = Calendar(identifier: .gregorian)
    monday.timeZone = TimeZone(identifier: "UTC")!
    monday.firstWeekday = 2
    var saturday = monday
    saturday.firstWeekday = 7
    // Monday 2026-11-30 12:00 UTC
    let now = Date(timeIntervalSince1970: 1_796_040_000)
    let m = Weeks(now: now, calendar: monday)
    let s = Weeks(now: now, calendar: saturday)
    #expect(monday.component(.weekday, from: m.thisStart) == 2)
    #expect(saturday.component(.weekday, from: s.thisStart) == 7)
    #expect(m.lastStart == m.thisStart.addingTimeInterval(-7 * 86_400))
    #expect(m.lastSameMoment == now.addingTimeInterval(-7 * 86_400))
}

@Test func weekChange() {
    #expect(Weeks.change(this: 124, last: 100) == 24)
    #expect(Weeks.change(this: 50, last: 100) == -50)
    #expect(Weeks.change(this: 5, last: 0) == nil)
}

@Test func heatSteps() {
    let t = HeatSteps.thresholds([0, 10, 20, 30, 40, 0])
    #expect(HeatSteps.step(0, thresholds: t) == 0)
    #expect(HeatSteps.step(10, thresholds: t) == 1)
    #expect(HeatSteps.step(40, thresholds: t) == 4)
}

@Test func familyOrderIsFixed() {
    #expect(ModelFamilies.rank("Fable") < ModelFamilies.rank("Opus"))
    #expect(ModelFamilies.rank("Unknown") == ModelFamilies.order.count)
}
