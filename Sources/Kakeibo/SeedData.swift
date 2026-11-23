import Foundation
import SwiftData

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with realistic limit readings.
/// Replace these with your app's own types. Seed only what a person can
/// create in the app, or the snapshots show features no one can use.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        let context = model.container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<LimitSnapshot>())) ?? 0) == 0 else { return }
        // Readings Kakeibo itself takes (S-003): one every 5 minutes, newest
        // matching docs/STORIES.md (Session 42%, Weekly 18%, Fable 63%).
        let now = Date.now
        let samples: [(Double, Double, Double?)] = [
            (42, 18, 63), (38, 17, 62), (31, 17, 61), (24, 16, 60), (92, 15, nil),
        ]
        for (index, sample) in samples.enumerated() {
            let snapshot = LimitSnapshot(
                sessionUsed: sample.0, sessionResets: now.addingTimeInterval(8_040),
                weeklyUsed: sample.1, weeklyResets: now.addingTimeInterval(4 * 86_400),
                fableUsed: sample.2, fableResets: sample.2.map { _ in now.addingTimeInterval(4 * 86_400) })
            snapshot.takenAt = now.addingTimeInterval(Double(-index) * 300)
            context.insert(snapshot)
        }
        // A Summary someone made today (S-021), so the Projects page shows one.
        context.insert(Summary(project: "/Users/me/Projects/Kakeibo", day: Calendar.current.startOfDay(for: now),
                               text: "Built the Dashboard's charts and the activity heatmap. Fixed snapshots that caught the wrong window.",
                               tokens: 4_100))
        try? context.save()
    }

    // MARK: Fixture logs (S-002, S-006, S-007)

    /// Where test runs read Claude Code logs from (UsageService.root).
    static let logsDirectory = URL(fileURLWithPath: "/tmp/Kakeibo-logs")

    /// Writes 30 days of Claude Code-style logs for five projects and three
    /// models. Today has 1.24 M tokens in five projects, so "+2 more" shows.
    static func writeLogs() {
        guard Store.isOverridden else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: logsDirectory)
        // (project, today's tokens split as input/output/cache write/cache read)
        let projects: [(String, Int)] = [
            ("/Users/me/Projects/Kakeibo", 412_000),
            ("/Users/me/Projects/garden-planner", 356_000),
            ("/Users/me/Projects/recipe-box", 268_000),
            ("/Users/me/Projects/weather-cli", 132_000),
            ("/Users/me/Desktop/portfolio-site-redesign-and-blog-migration", 72_000),
        ]
        let models = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-2"]
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 0, minute: 30, second: 0, of: .now) ?? .now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var serial = 0
        for (index, (project, todayTokens)) in projects.enumerated() {
            let folder = logsDirectory.appending(path: project.replacingOccurrences(of: "/", with: "-"))
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            var lines: [String] = []
            for day in 0..<30 {
                // Older days vary so charts have shape; today is exact.
                let scale = day == 0 ? 1.0 : 0.3 + Double((day * 7 + index * 3) % 10) / 10
                let total = Int(Double(todayTokens) * scale)
                guard total > 0, !(day > 0 && (day + index) % 6 == 0) else { continue }
                let time = calendar.date(byAdding: .day, value: -day, to: noon)!.addingTimeInterval(Double(index) * 60)
                let model = models[(day + index) % models.count]
                let output = total / 50, write = total / 10, input = total / 100
                let read = total - output - write - input
                serial += 1
                if day == 0 {
                    // Today's prompt and edit, so Summarize has a digest (S-020).
                    let stamp = formatter.string(from: time.addingTimeInterval(-30))
                    lines.append(#"{"type":"user","cwd":"\#(project)","timestamp":"\#(stamp)","sessionId":"seed-\#(index)","message":{"role":"user","content":"Add the activity heatmap to the Dashboard"}}"#)
                    lines.append(#"{"type":"assistant","cwd":"\#(project)","timestamp":"\#(stamp)","sessionId":"seed-\#(index)","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"\#(project)/Sources/Dashboard.swift"}}]}}"#)
                }
                lines.append(#"{"message":{"model":"\#(model)","id":"msg_seed_\#(serial)","type":"message","role":"assistant","content":[],"usage":{"input_tokens":\#(input),"cache_creation_input_tokens":\#(write),"cache_read_input_tokens":\#(read),"output_tokens":\#(output),"cache_creation":{"ephemeral_1h_input_tokens":\#(write),"ephemeral_5m_input_tokens":0}}},"requestId":"req_seed_\#(serial)","type":"assistant","timestamp":"\#(formatter.string(from: time))","cwd":"\#(project)","sessionId":"seed-\#(index)"}"#)
            }
            try? (lines.joined(separator: "\n") + "\n").write(to: folder.appending(path: "seed.jsonl"), atomically: true, encoding: .utf8)
        }
    }
}
