import Foundation

/// Daily values for a small line (S-050): one per day, oldest first, 0 on
/// days without activity.
public enum Sparkline {
    public static func points(_ days: [Date: Int], endingOn end: Date, count: Int = 14,
                              calendar: Calendar = .current) -> [Int] {
        let last = calendar.startOfDay(for: end)
        return (0..<count).reversed().map { back in
            let day = calendar.date(byAdding: .day, value: -back, to: last) ?? last
            return days[day] ?? 0
        }
    }
}
