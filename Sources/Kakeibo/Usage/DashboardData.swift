import Foundation
import KakeiboKit

/// The Dashboard's range: the last 7 or 30 days (S-011, S-014, S-015).
enum DashboardRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30

    var id: Int { rawValue }
    var title: String { "\(rawValue) Days" }

    func start(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(rawValue - 1), to: calendar.startOfDay(for: now)) ?? now
    }
}

/// Everything the Dashboard draws, read once from the UsageStore actor.
struct DashboardData: Equatable {
    struct DayFamily: Identifiable, Equatable {
        var id: String { "\(day.timeIntervalSince1970)-\(family)" }
        let day: Date
        let family: String
        let totals: UsageTotals
    }

    struct Project: Identifiable, Equatable {
        /// The full path Claude Code worked in.
        let id: String
        var name: String { (id as NSString).lastPathComponent }
        let totals: UsageTotals
    }

    var byDay: [DayFamily] = []
    var families: [(family: String, totals: UsageTotals)] = []
    var projects: [Project] = []
    var thisWeek = UsageTotals()
    var lastWeekSoFar = UsageTotals()
    var hasAnyActivity = false
    /// False until the first read, so the empty state never flashes.
    var loaded = false

    static func == (a: DashboardData, b: DashboardData) -> Bool {
        a.byDay == b.byDay && a.projects == b.projects && a.thisWeek == b.thisWeek
            && a.lastWeekSoFar == b.lastWeekSoFar && a.hasAnyActivity == b.hasAnyActivity && a.loaded == b.loaded
            && a.families.map(\.family) == b.families.map(\.family)
    }
}

extension UsageService {
    func dashboard(range: DashboardRange, now: Date = .now) async -> DashboardData {
        let start = range.start(now: now)
        let weeks = Weeks(now: now)
        var data = DashboardData()
        data.byDay = await store.byDayAndFamily(from: start).map { .init(day: $0.day, family: $0.family, totals: $0.totals) }
        data.families = await store.byModelFamily(from: start)
            .sorted { ModelFamilies.rank($0.family) < ModelFamilies.rank($1.family) }
        data.projects = await store.byProject(from: start).map { .init(id: $0.project, totals: $0.totals) }
        data.thisWeek = await store.total(from: weeks.thisStart)
        data.lastWeekSoFar = await store.total(from: weeks.lastStart, to: weeks.lastSameMoment)
        data.hasAnyActivity = await !store.records.isEmpty
        data.loaded = true
        return data
    }

    /// A year of daily Tokens for the heatmap, for every Project or one (S-016).
    func heatmap(project: String?, now: Date = .now, calendar: Calendar = .current) async -> [Date: Int] {
        let start = calendar.date(byAdding: .day, value: -371, to: calendar.startOfDay(for: now)) ?? now
        var days: [Date: Int] = [:]
        for entry in await store.byDay(from: start, project: project) { days[entry.day] = entry.totals.tokens }
        return days
    }

    /// Every Project with activity in the last year, most Tokens first.
    func yearProjects(now: Date = .now) async -> [String] {
        let start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return await store.byProject(from: start).map(\.project)
    }
}

extension UsageService {
    /// Today's sessions per Project, busiest Project first (S-051, S-052).
    /// Reads the Projects' log files off the main thread.
    func timeline() async -> [(project: String, sessions: [TimelineSession])] {
        let start = Calendar.current.startOfDay(for: .now)
        var result: [(project: String, sessions: [TimelineSession])] = []
        for project in todayByProject.map(\.id) {
            let files = await store.files(of: project)
            let sessions = await Task.detached(priority: .userInitiated) {
                Timeline.build(lines: files.flatMap(ClaudeCLI.lines), project: project, from: start)
            }.value
            if !sessions.isEmpty { result.append((project, sessions)) }
        }
        return result
    }
}
