import Foundation
import Testing
@testable import KakeiboKit

private let resets = Date(timeIntervalSince1970: 1_000_000)
private func window(_ used: Double, _ reset: Date? = resets) -> LimitWindow { LimitWindow(used: used, resets: reset) }

/// Feeds readings through the rules and returns every event.
private func run(_ readings: [LimitWindow]) -> [AlertEvent] {
    var state = LimitAlertState()
    var events: [AlertEvent] = []
    for reading in readings {
        let out = AlertRules.evaluate(limit: "Session", state: state, window: reading)
        events += out.events
        state = out.state
    }
    return events
}

@Test func eachThresholdAlertsOncePerPeriod() {
    let events = run([window(50), window(81), window(85), window(91), window(95)])
    #expect(events == [
        .almostReached(limit: "Session", threshold: 80, used: 81, resets: resets),
        .almostReached(limit: "Session", threshold: 90, used: 91, resets: resets),
    ])
}

@Test func aJumpPastBothAlertsNinetyOnly() {
    #expect(run([window(10), window(95)]) == [.almostReached(limit: "Session", threshold: 90, used: 95, resets: resets)])
}

@Test func resetAlertsOnlyAfterEightyPercent() {
    let later = resets.addingTimeInterval(5 * 3600)
    let events = run([window(85), window(3, later)])
    #expect(events.last == .reset(limit: "Session"))
    #expect(!run([window(60), window(3, later)]).contains(.reset(limit: "Session")))
}

@Test func thresholdsAlertAgainInTheNextPeriod() {
    let later = resets.addingTimeInterval(5 * 3600)
    let events = run([window(82), window(2, later), window(83, later)])
    #expect(events.filter { if case .almostReached = $0 { true } else { false } }.count == 2)
}

@Test func resetWithoutResetTimes() {
    #expect(run([window(88, nil), window(1, nil)]).last == .reset(limit: "Session"))
}

@Test func alertWords() {
    let now = Date(timeIntervalSince1970: 0)
    let event = AlertEvent.almostReached(limit: "Session", threshold: 90, used: 90, resets: now.addingTimeInterval(38 * 60 + 20))
    #expect(event.title(now: now) == "Session limit 90% used · Resets in 38 m")
    #expect(AlertEvent.reset(limit: "Session").title() == "Session limit reset. You're back to 0%.")
    #expect(AlertEvent.daily(tokens: 1_240_000, cost: 18.4, topProject: "Kakeibo").title() == "Today: 1.24 M tokens · $18.40 · mostly Kakeibo")
}

@Test func dailyFiresOnceAfterItsTimeOnActiveDays() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let evening = Date(timeIntervalSince1970: 1_796_040_000 + 10 * 3600) // 22:00 UTC
    let morning = Date(timeIntervalSince1970: 1_796_040_000 - 4 * 3600)  // 08:00 UTC
    #expect(DailyAlert.shouldFire(now: evening, hour: 21, minute: 0, lastFired: nil, hasActivity: true, calendar: calendar))
    #expect(!DailyAlert.shouldFire(now: morning, hour: 21, minute: 0, lastFired: nil, hasActivity: true, calendar: calendar))
    #expect(!DailyAlert.shouldFire(now: evening, hour: 21, minute: 0, lastFired: evening.addingTimeInterval(-600), hasActivity: true, calendar: calendar))
    #expect(!DailyAlert.shouldFire(now: evening, hour: 21, minute: 0, lastFired: nil, hasActivity: false, calendar: calendar))
}
