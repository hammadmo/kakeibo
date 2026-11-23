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

/// The Weekly limit split by where Claude was used (S-017).
public struct SurfaceBreakdown: Equatable, Sendable {
    public struct Row: Equatable, Sendable, Identifiable {
        public var id: String
        /// Anthropic's name: "Claude Code", "Chats", "Cowork", "Other".
        public var name: String
        /// Share of this week's use, 0...100.
        public var shareOfUse: Double
        /// Share of the whole Weekly limit, 0...100.
        public var shareOfLimit: Double

        public init(id: String, name: String, shareOfUse: Double, shareOfLimit: Double) {
            self.id = id
            self.name = name
            self.shareOfUse = shareOfUse
            self.shareOfLimit = shareOfLimit
        }
    }

    public var rows: [Row]
    public var asOf: Date?
    public var weekStarted: Date?

    public init(rows: [Row], asOf: Date? = nil, weekStarted: Date? = nil) {
        self.rows = rows
        self.asOf = asOf
        self.weekStarted = weekStarted
    }
}

/// The three limits Kakeibo shows. A plan without a Fable limit has `fable == nil`.
public struct Limits: Equatable, Sendable {
    public var session: LimitWindow?
    public var weekly: LimitWindow?
    public var fable: LimitWindow?
    /// Every window key the response had, for `--probe-limits`.
    public var keys: [String] = []
    /// nil when the response has no `seven_day_breakdown`.
    public var breakdown: SurfaceBreakdown?

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
        limits.breakdown = decodeBreakdown(object["seven_day_breakdown"])
        return limits
    }

    static func decodeBreakdown(_ value: Any?) -> SurfaceBreakdown? {
        guard let object = value as? [String: Any], let rows = object["rows"] as? [[String: Any]] else { return nil }
        let parsed = rows.compactMap { row -> SurfaceBreakdown.Row? in
            guard let name = row["display_name"] as? String else { return nil }
            return SurfaceBreakdown.Row(
                id: row["key"] as? String ?? name, name: name,
                shareOfUse: (row["percent"] as? NSNumber)?.doubleValue ?? 0,
                shareOfLimit: (row["percent_of_limit"] as? NSNumber)?.doubleValue ?? 0)
        }
        guard !parsed.isEmpty else { return nil }
        return SurfaceBreakdown(rows: parsed,
                                asOf: (object["as_of"] as? String).flatMap(parseDate),
                                weekStarted: (object["window_started_at"] as? String).flatMap(parseDate))
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
        // The Mac's own clock style ("Thu 4:52 PM" or "Thu 16:52"); a fixed
        // two-digit hour without AM/PM read 4:52 PM as "04:52".
        var style = Date.FormatStyle(calendar: calendar).weekday(.abbreviated).hour().minute()
        style.timeZone = calendar.timeZone
        return "Resets \(date.formatted(style))"
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
