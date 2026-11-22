import Foundation
import Observation
import KakeiboKit

/// Today's Tokens and Cost from Claude Code's logs, for the popover.
/// The parsing runs in `UsageStore` (an actor, off the main thread).
@MainActor
@Observable
final class UsageService {
    struct ProjectRow: Identifiable, Equatable {
        /// The full path Claude Code worked in.
        let id: String
        var name: String { (id as NSString).lastPathComponent }
        let totals: UsageTotals
    }

    private(set) var today = UsageTotals()
    private(set) var todayByProject: [ProjectRow] = []
    private(set) var isReading = false
    private(set) var hasRead = false
    let store: UsageStore

    /// Test runs read fixture logs (SeedData writes them), never ~/.claude.
    static var root: URL {
        if let path = ProcessInfo.processInfo.environment["APP_LOGS"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        if Store.isOverridden { return SeedData.logsDirectory }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")
    }

    init() {
        store = UsageStore(root: Self.root)
    }

    private var timer: Task<Void, Never>?

    /// Re-reads new log lines every minute; an unchanged log costs one stat.
    func start() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func refresh() async {
        guard !isReading else { return }
        isReading = true
        defer { isReading = false }
        await store.refresh()
        let midnight = Calendar.current.startOfDay(for: .now)
        today = await store.total(from: midnight)
        todayByProject = await store.byProject(from: midnight).map { ProjectRow(id: $0.project, totals: $0.totals) }
        hasRead = true
    }
}
