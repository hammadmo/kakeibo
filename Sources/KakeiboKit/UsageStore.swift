import Foundation

/// Totals for one slice: a day, a model, a project.
public struct UsageTotals: Equatable, Sendable {
    public var tokens = 0
    public var cost = 0.0
    public var replies = 0
    /// The newest reply in the slice.
    public var last: Date?

    public init(tokens: Int = 0, cost: Double = 0, replies: Int = 0, last: Date? = nil) {
        self.tokens = tokens
        self.cost = cost
        self.replies = replies
        self.last = last
    }

    mutating func add(_ record: UsageRecord) {
        tokens += record.tokens
        cost += record.cost
        replies += 1
        if last.map({ record.time > $0 }) ?? true { last = record.time }
    }
}

/// Reads every log under a root once, then only the bytes added since.
/// Safe to call `refresh()` often: an unchanged file costs one `stat`.
public actor UsageStore {
    public let root: URL
    private var offsets: [String: UInt64] = [:]
    private var seen: Set<String> = []
    public private(set) var records: [UsageRecord] = []
    /// Which log files hold each Project's replies, for the Summary digest.
    private var filesByProject: [String: Set<String>] = [:]

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")) {
        self.root = root
    }

    /// Returns how many new records were read. Files are parsed in parallel.
    @discardableResult
    public func refresh() async -> Int {
        let before = records.count
        let keys: [URLResourceKey] = [.fileSizeKey]
        var jobs: [(path: String, url: URL, start: UInt64, project: String)] = []
        for url in Self.logFiles(under: root, keys: keys) {
            let size = UInt64((try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0)
            var start = offsets[url.path] ?? 0
            if size < start { start = 0 } // the file was replaced
            if size > start { jobs.append((url.path, url, start, Self.projectName(for: url))) }
        }
        let results = await withTaskGroup(of: (String, UInt64, (consumed: UInt64, records: [UsageRecord])).self) { group in
            for job in jobs {
                group.addTask { (job.path, job.start, Self.read(job.url, from: job.start, project: job.project)) }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        for (path, start, read) in results {
            offsets[path] = start + read.consumed
            for record in read.records {
                filesByProject[record.project, default: []].insert(path)
                if seen.insert(record.key).inserted { records.append(record) }
            }
        }
        return records.count - before
    }

    private static func logFiles(under root: URL, keys: [URLResourceKey]) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    /// Reads whole lines from `start`; `consumed` stops before a line still
    /// being written, so it is read next time.
    private static func read(_ url: URL, from start: UInt64, project: String) -> (consumed: UInt64, records: [UsageRecord]) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return (0, []) }
        defer { try? handle.close() }
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return (0, []) }
        var consumed = 0
        var found: [UsageRecord] = []
        data.withUnsafeBytes { (all: UnsafeRawBufferPointer) in
            guard let base = all.baseAddress else { return }
            var lineStart = 0
            while lineStart < all.count,
                  let hit = memchr(base + lineStart, 0x0A, all.count - lineStart) {
                let end = base.distance(to: UnsafeRawPointer(hit))
                if let record = UsageLog.parse(bytes: UnsafeRawBufferPointer(rebasing: all[lineStart..<end]),
                                               fallbackProject: project) {
                    found.append(record)
                }
                lineStart = end + 1
                consumed = lineStart
            }
        }
        return (UInt64(consumed), found)
    }

    /// "-Users-me-Projects-Kakeibo" → "/Users/me/Projects/Kakeibo" (best effort).
    private static func projectName(for url: URL) -> String {
        let folder = url.deletingLastPathComponent().lastPathComponent
        return folder.replacingOccurrences(of: "-", with: "/")
    }

    /// The log files that hold a Project's replies.
    public func files(of project: String) -> [URL] {
        (filesByProject[project] ?? []).sorted().map { URL(fileURLWithPath: $0) }
    }

    /// Sessions whose newest reply is under `window` seconds old, newest first,
    /// with every token the session used (S-052).
    public func liveSessions(now: Date = .now, window: TimeInterval = TimelineSession.liveWindow) -> [LiveSession] {
        var sessions: [String: LiveSession] = [:]
        for r in records where !r.session.isEmpty {
            var s = sessions[r.session] ?? LiveSession(id: r.session, project: r.project, tokens: 0, last: r.time)
            s.tokens += r.tokens
            if r.time > s.last { s.last = r.time; s.project = r.project }
            sessions[r.session] = s
        }
        return sessions.values.filter { now.timeIntervalSince($0.last) < window }.sorted { $0.last > $1.last }
    }

    // MARK: Summaries

    public func total(from start: Date, to end: Date = .distantFuture) -> UsageTotals {
        records.reduce(into: UsageTotals()) { sum, r in
            if r.time >= start && r.time < end { sum.add(r) }
        }
    }

    public func byProject(from start: Date, to end: Date = .distantFuture) -> [(project: String, totals: UsageTotals)] {
        group(from: start, to: end) { $0.project }
    }

    public func byModelFamily(from start: Date, to end: Date = .distantFuture) -> [(family: String, totals: UsageTotals)] {
        group(from: start, to: end) { Pricing.family(of: $0.model) }.map { ($0.project, $0.totals) }
    }

    /// Local calendar days, oldest first; days without activity are omitted.
    /// `project` limits it to one Project's path.
    public func byDay(from start: Date, project: String? = nil, calendar: Calendar = .current) -> [(day: Date, totals: UsageTotals)] {
        var days: [Date: UsageTotals] = [:]
        for r in records where r.time >= start && (project == nil || r.project == project) {
            days[calendar.startOfDay(for: r.time), default: UsageTotals()].add(r)
        }
        return days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// One entry per day and model family, oldest first.
    public func byDayAndFamily(from start: Date, calendar: Calendar = .current) -> [(day: Date, family: String, totals: UsageTotals)] {
        var cells: [Date: [String: UsageTotals]] = [:]
        for r in records where r.time >= start {
            cells[calendar.startOfDay(for: r.time), default: [:]][Pricing.family(of: r.model), default: UsageTotals()].add(r)
        }
        return cells.sorted { $0.key < $1.key }.flatMap { day, families in
            families.sorted { $0.key < $1.key }.map { (day, $0.key, $0.value) }
        }
    }

    private func group(from start: Date, to end: Date, by key: (UsageRecord) -> String) -> [(project: String, totals: UsageTotals)] {
        var groups: [String: UsageTotals] = [:]
        for r in records where r.time >= start && r.time < end {
            groups[key(r), default: UsageTotals()].add(r)
        }
        return groups.sorted { $0.value.tokens > $1.value.tokens }.map { ($0.key, $0.value) }
    }
}

/// A Claude Code session that replied in the last few minutes (S-052).
public struct LiveSession: Equatable, Sendable, Identifiable {
    public var id: String
    public var project: String
    public var tokens: Int
    public var last: Date
}
