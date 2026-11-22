import Foundation
import SwiftData

/// One reading of the plan limits (docs/BRIEF.md: LimitSnapshot).
/// Fable is optional: a plan without a Fable limit hides that Gauge.
@Model
final class LimitSnapshot {
    var takenAt: Date = Date.now
    var sessionUsed: Double
    var sessionResets: Date
    var weeklyUsed: Double
    var weeklyResets: Date
    var fableUsed: Double?
    var fableResets: Date?

    init(sessionUsed: Double, sessionResets: Date, weeklyUsed: Double, weeklyResets: Date,
         fableUsed: Double? = nil, fableResets: Date? = nil) {
        self.sessionUsed = sessionUsed
        self.sessionResets = sessionResets
        self.weeklyUsed = weeklyUsed
        self.weeklyResets = weeklyResets
        self.fableUsed = fableUsed
        self.fableResets = fableResets
    }
}

/// The Dashboard pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .projects: "Projects"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .projects: "folder"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let container: ModelContainer
    var sidebar: SidebarItem? = .overview
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    let limits: LimitsService

    init(container: ModelContainer) {
        self.container = container
        self.limits = LimitsService(container: container)
    }
}
