import Foundation

/// One plan limit: how much is Used and when it Resets.
public struct LimitWindow: Equatable, Sendable {
    public var used: Double
    public var resets: Date?

    public init(used: Double, resets: Date?) {
        self.used = used
        self.resets = resets
    }
}

/// The three limits Kakeibo shows. A plan without a Fable limit has `fable == nil`.
public struct Limits: Equatable, Sendable {
    public var session: LimitWindow?
    public var weekly: LimitWindow?
    public var fable: LimitWindow?
    /// Every window key the response had, for `--probe-limits`.
    public var keys: [String] = []

    public init(session: LimitWindow? = nil, weekly: LimitWindow? = nil, fable: LimitWindow? = nil, keys: [String] = []) {
        self.session = session
        self.weekly = weekly
        self.fable = fable
        self.keys = keys
    }

    /// Decodes the OAuth usage response Claude Code's `/usage` reads. The
    /// endpoint is not documented. Its `limits` array is read first:
    /// `kind` "session" is the Session limit, "weekly_all" the Weekly limit,
    /// and a "weekly_scoped" limit whose model is named Fable the Fable limit.
    /// Older responses only have `five_hour` and `seven_day` objects with
    /// `utilization` and `resets_at`; those are the fallback.
    public static func decode(_ data: Data) throws -> Limits {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not an object"))
        }
        var windows: [String: LimitWindow] = [:]
        for (key, value) in object {
            guard let window = value as? [String: Any],
                  let used = (window["utilization"] as? NSNumber)?.doubleValue else { continue }
            windows[key] = LimitWindow(used: used, resets: (window["resets_at"] as? String).flatMap(parseDate))
        }
        var limits = Limits(session: windows["five_hour"], weekly: windows["seven_day"],
                            fable: windows.first { $0.key.hasPrefix("seven_day") && $0.key.contains("fable") }?.value)
        var keys = windows.keys.sorted()

        for entry in object["limits"] as? [[String: Any]] ?? [] {
            guard let kind = entry["kind"] as? String,
                  let used = (entry["percent"] as? NSNumber)?.doubleValue else { continue }
            let window = LimitWindow(used: used, resets: (entry["resets_at"] as? String).flatMap(parseDate))
            let model = ((entry["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String
            keys.append(model.map { "limits.\(kind)(\($0))" } ?? "limits.\(kind)")
            switch kind {
            case "session": limits.session = window
            case "weekly_all": limits.weekly = window
            case "weekly_scoped" where model?.localizedCaseInsensitiveContains("fable") == true: limits.fable = window
            default: break
            }
        }
        limits.keys = keys
        return limits
    }

    static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

/// "Resets in 2 h 14 m", "Resets in 38 m", "Resets Mon 09:00".
public enum ResetText {
    public static func short(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date else { return "" }
        let seconds = max(date.timeIntervalSince(now), 0)
        if seconds < 60 { return "Resets now" }
        if seconds < 24 * 3600 {
            let minutes = Int(seconds / 60)
            let h = minutes / 60, m = minutes % 60
            return h > 0 ? "Resets in \(h) h \(m) m" : "Resets in \(m) m"
        }
        let day = date.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated))
        let time = date.formatted(Date.FormatStyle(calendar: calendar).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "Resets \(day) \(time)"
    }

    /// For VoiceOver: "resets in 2 hours 14 minutes".
    public static func spoken(_ date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        let minutes = Int(max(date.timeIntervalSince(now), 0) / 60)
        let h = minutes / 60, m = minutes % 60
        if h >= 24 { return "resets \(date.formatted(.dateTime.weekday(.wide).hour().minute()))" }
        let hours = h == 1 ? "1 hour" : "\(h) hours"
        let mins = m == 1 ? "1 minute" : "\(m) minutes"
        return "resets in " + (h > 0 ? "\(hours) \(mins)" : mins)
    }
}
