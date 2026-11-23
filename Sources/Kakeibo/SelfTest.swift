import AppKit
import SwiftData
import KakeiboKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Kakeibo-self.store ~/Applications/Kakeibo.app/Contents/MacOS/Kakeibo --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func snapshots() -> [LimitSnapshot] { (try? context.fetch(FetchDescriptor<LimitSnapshot>())) ?? [] }

            let before = snapshots().count
            let reading = LimitSnapshot(sessionUsed: 42, sessionResets: .now, weeklyUsed: 18, weeklyResets: .now)
            context.insert(reading)
            try? context.save()
            check("a limit reading is stored", snapshots().count == before + 1)
            check("a plan without Fable stores no Fable reading", reading.fableUsed == nil)
            context.delete(reading)
            try? context.save()
            check("deleting the reading removes it", snapshots().count == before)

            model.sidebar = .projects
            check("the Projects page opens", model.sidebar == .projects)
            check("92% is almost reached", Used(92).isAlmostReached)

            // S-003: fixture limits, and no second fetch within a minute.
            let fetched = await model.limits.fetch(force: true)
            check("limits load", fetched && model.limits.status == .ok && model.limits.current?.session?.used == 42)
            check("Fable limit is read", model.limits.current?.fable?.used == 63)
            let again = await model.limits.fetch()
            check("a second fetch within a minute is skipped", !again)

            // S-006, S-007: today's totals from the fixture logs.
            SeedData.writeLogs()
            await model.usage.refresh()
            check("today's tokens are read from the logs", model.usage.today.tokens == 1_240_000,
                  "\(model.usage.today.tokens)")
            check("today's cost is estimated", model.usage.today.cost > 0)
            check("five Projects today, most first",
                  model.usage.todayByProject.count == 5 && model.usage.todayByProject.first?.name == "Kakeibo")

            // S-008: Refresh re-reads logs but doesn't fetch limits again within a minute.
            let lastUpdate = model.limits.updatedAt
            await model.refreshNow()
            check("Refresh within a minute keeps the last limits", model.limits.updatedAt == lastUpdate)

            // S-014: the header buttons' sorts.
            let rows = [DashboardData.Project(id: "/a/beta", totals: UsageTotals(tokens: 10, cost: 5, last: .now)),
                        DashboardData.Project(id: "/a/alpha", totals: UsageTotals(tokens: 30, cost: 1, last: .distantPast))]
            check("Projects sort by Tokens, Cost, name, and last active",
                  ProjectSort.tokens.sorted(rows).first?.name == "alpha" && ProjectSort.cost.sorted(rows).first?.name == "beta"
                    && ProjectSort.name.sorted(rows).first?.name == "alpha" && ProjectSort.last.sorted(rows).first?.name == "beta")

            // S-012: this week against last week, from the fixture logs.
            let dashboard = await model.usage.dashboard(range: .month)
            check("the Dashboard reads this week, the model split, and days",
                  dashboard.thisWeek.tokens > 0 && dashboard.families.count == 3 && !dashboard.byDay.isEmpty)

            // S-020 to S-022: Summarize through a fake Claude Code CLI (no tokens spent).
            let kakeibo = "/Users/me/Projects/Kakeibo"
            let fake = "/tmp/Kakeibo-fake-claude"
            func fakeCLI(_ script: String) {
                try? ("#!/bin/sh\ncat > /dev/null\n" + script).write(toFile: fake, atomically: true, encoding: .utf8)
                chmod(fake, 0o755)
                setenv("APP_CLAUDE", fake, 1)
            }
            @MainActor func summarize() async {
                model.summaries.summarize(kakeibo)
                while model.summaries.isRunning(kakeibo) { try? await Task.sleep(for: .milliseconds(50)) }
            }
            func todaysSummaries() -> [Summary] {
                let day = Calendar.current.startOfDay(for: .now)
                return ((try? context.fetch(FetchDescriptor<Summary>())) ?? []).filter { $0.project == kakeibo && $0.day == day }
            }
            fakeCLI(#"echo '{"type":"result","is_error":false,"result":"Built the heatmap. Fixed snapshots.","usage":{"input_tokens":2,"output_tokens":40,"cache_creation_input_tokens":4000,"cache_read_input_tokens":100}}'"#)
            await summarize()
            check("Summarize stores today's Summary with its tokens",
                  model.summaries.today(kakeibo)?.text == "Built the heatmap. Fixed snapshots." && model.summaries.today(kakeibo)?.tokens == 4142,
                  model.summaries.errors[kakeibo] ?? "")
            await summarize()
            check("Summarize Again keeps one Summary per Project and day", todaysSummaries().count == 1)

            fakeCLI("echo 'Claude usage limit reached.' >&2\nexit 1")
            await summarize()
            check("a failed run shows the CLI's first error line",
                  model.summaries.errors[kakeibo] == "Claude usage limit reached." && !model.summaries.isRunning(kakeibo),
                  model.summaries.errors[kakeibo] ?? "nil")

            setenv("APP_CLAUDE", "/tmp/Kakeibo-no-such-claude", 1)
            await summarize()
            check("a missing CLI says how to fix it",
                  model.summaries.errors[kakeibo] == "Unable to find Claude Code. Install it, then try again.")

            fakeCLI("sleep 30")
            model.summaries.summarize(kakeibo)
            try? await Task.sleep(for: .milliseconds(200))
            model.summaries.cancel(kakeibo)
            check("Cancel stops a run", !model.summaries.isRunning(kakeibo))
            unsetenv("APP_CLAUDE")

            // S-009: old readings are deleted, recent ones kept.
            let old = LimitSnapshot(sessionUsed: 1, sessionResets: .now, weeklyUsed: 1, weeklyResets: .now)
            old.takenAt = Date.now.addingTimeInterval(-91 * 86_400)
            let recent = LimitSnapshot(sessionUsed: 2, sessionResets: .now, weeklyUsed: 2, weeklyResets: .now)
            context.insert(old)
            context.insert(recent)
            try? context.save()
            model.limits.pruneOld()
            let left = snapshots()
            check("readings older than 90 days are deleted", !left.contains { $0.sessionUsed == 1 } && left.contains { $0.sessionUsed == 2 })

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
