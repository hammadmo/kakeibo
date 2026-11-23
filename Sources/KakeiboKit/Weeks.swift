import Foundation

/// This week and last week, starting on the locale's first weekday (S-012).
public struct Weeks: Equatable, Sendable {
    public let thisStart: Date
    public let lastStart: Date
    /// The same moment last week, so a partial week compares with a partial week.
    public let lastSameMoment: Date

    public init(now: Date = .now, calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        thisStart = start
        lastStart = calendar.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        lastSameMoment = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
    }

    /// +24 means 24% more than last week; nil when last week had nothing.
    public static func change(this: Double, last: Double) -> Int? {
        guard last > 0 else { return nil }
        return Int(((this - last) / last * 100).rounded())
    }
}

/// The models in the order their colors are assigned. Never reordered, so a
/// model keeps its color when another one drops out of the range.
public enum ModelFamilies {
    public static let order = ["Fable", "Opus", "Sonnet", "Haiku", "Other"]

    public static func rank(_ family: String) -> Int { order.firstIndex(of: family) ?? order.count }
}

/// Heatmap steps: 0 for no activity, then 1...4 by quartile of active days.
public enum HeatSteps {
    public static func thresholds(_ values: [Int]) -> [Int] {
        let active = values.filter { $0 > 0 }.sorted()
        guard !active.isEmpty else { return [1, 1, 1] }
        func q(_ f: Double) -> Int { active[min(Int(Double(active.count - 1) * f), active.count - 1)] }
        return [q(0.25), q(0.5), q(0.75)]
    }

    public static func step(_ value: Int, thresholds t: [Int]) -> Int {
        guard value > 0 else { return 0 }
        if value <= t[0] { return 1 }
        if value <= t[1] { return 2 }
        if value <= t[2] { return 3 }
        return 4
    }
}
