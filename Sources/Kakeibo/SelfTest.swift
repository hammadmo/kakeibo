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
