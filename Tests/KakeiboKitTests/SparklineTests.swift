import Foundation
import Testing
@testable import KakeiboKit

@Test func sparklineHasOnePointPerDayWithZeros() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_796_040_000))
    let days = [today: 5, calendar.date(byAdding: .day, value: -2, to: today)!: 3,
                calendar.date(byAdding: .day, value: -20, to: today)!: 99]
    let points = Sparkline.points(days, endingOn: today, calendar: calendar)
    #expect(points.count == 14)
    #expect(points.last == 5)
    #expect(points[11] == 3)
    #expect(points.reduce(0, +) == 8) // the day 20 days back is outside
}
