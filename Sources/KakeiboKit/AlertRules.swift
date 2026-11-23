import Foundation

/// One Alert Kakeibo sends (S-030 to S-032).
public enum AlertEvent: Equatable, Sendable {
    /// A limit reached 80% or 90%.
    case almostReached(limit: String, threshold: Int, used: Double, resets: Date?)
    /// A limit that was at 80% or more went back to 0%.
    case reset(limit: String)
    /// The end-of-day numbers.
    case daily(tokens: Int, cost: Double, topProject: String?)

    /// One notification per limit and kind, so a newer one replaces the older.
    public var identifier: String {
        switch self {
        case .almostReached(let limit, _, _, _): "limit-\(limit)"
        case .reset(let limit): "reset-\(limit)"
        case .daily: "daily"
        }
    }

    public func title(now: Date = .now) -> String {
        switch self {
        case .almostReached(let limit, _, let used, let resets):
            let reset = ResetText.short(resets, now: now)
            return "\(limit) limit \(Used(used).label) used" + (reset.isEmpty ? "" : " · \(reset)")
        case .reset(let limit):
            return "\(limit) limit reset. You're back to 0%."
        case .daily(let tokens, let cost, let top):
            return "Today: \(Format.tokens(tokens)) tokens · \(Format.cost(cost))" + (top.map { " · mostly \($0)" } ?? "")
        }
    }
}

/// What Kakeibo remembers about one limit between readings.
public struct LimitAlertState: Codable, Equatable, Sendable {
    /// The highest threshold already alerted in this reset period: 0, 80, or 90.
    public var alerted = 0
    /// When this period resets, as last read.
    public var resets: Date?
    /// The highest Used % seen in this period.
    public var peak = 0.0

    public init(alerted: Int = 0, resets: Date? = nil, peak: Double = 0) {
        self.alerted = alerted
        self.resets = resets
        self.peak = peak
    }
}

/// The rules for limit Alerts, as a pure function of the last state and a new reading.
public enum AlertRules {
    public static let thresholds = [80, 90]

    /// A new period starts when the reset time moves later by more than a
    /// minute, or, without reset times, when Used falls from 80%+ to under 5%.
    static func isNewPeriod(_ state: LimitAlertState, _ window: LimitWindow) -> Bool {
        if let old = state.resets, let new = window.resets { return new.timeIntervalSince(old) > 60 }
        return state.peak >= 80 && window.used < 5
    }

    /// Returns the Alerts this reading earns and the state to keep. Each
    /// threshold alerts once per period; a jump past both alerts 90% only.
    public static func evaluate(limit: String, state: LimitAlertState, window: LimitWindow)
        -> (events: [AlertEvent], state: LimitAlertState) {
        var state = state
        var events: [AlertEvent] = []
        if isNewPeriod(state, window) {
            if state.peak >= 80 { events.append(.reset(limit: limit)) }
            state = LimitAlertState()
        }
        state.resets = window.resets ?? state.resets
        state.peak = max(state.peak, window.used)
        if let crossed = thresholds.last(where: { window.used >= Double($0) }), crossed > state.alerted {
            events.append(.almostReached(limit: limit, threshold: crossed, used: window.used, resets: window.resets))
            state.alerted = crossed
        }
        return (events, state)
    }
}

/// When the daily numbers Alert goes out (S-032).
public enum DailyAlert {
    /// True once a day, at or after `hour:minute`, on days with activity.
    public static func shouldFire(now: Date, hour: Int, minute: Int, lastFired: Date?, hasActivity: Bool,
                                  calendar: Calendar = .current) -> Bool {
        guard hasActivity,
              let due = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now), now >= due
        else { return false }
        if let lastFired, calendar.isDate(lastFired, inSameDayAs: now) { return false }
        return true
    }
}
