import Foundation
import Testing
@testable import KakeiboKit

/// KAKEIBO_BENCH=1 swift test --filter realLogs: times a full read of ~/.claude/projects.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KAKEIBO_BENCH"] == "1"))
func realLogs() async {
    let store = UsageStore()
    let start = Date.now
    let count = await store.refresh()
    let first = Date.now.timeIntervalSince(start)
    let again = Date.now
    await store.refresh()
    print("BENCH \(count) records in \(String(format: "%.2f", first)) s; second refresh \(String(format: "%.3f", Date.now.timeIntervalSince(again))) s")
    let today = await store.total(from: Calendar.current.startOfDay(for: .now))
    print("BENCH today \(today.tokens) tokens $\(String(format: "%.2f", today.cost))")
}
