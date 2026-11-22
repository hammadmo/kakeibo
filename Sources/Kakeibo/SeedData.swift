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
        try? context.save()
    }
}
