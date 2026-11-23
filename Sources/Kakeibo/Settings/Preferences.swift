import Foundation
import Observation
import ServiceManagement

/// What the menu bar item shows (S-040).
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case gaugeOnly, session, sessionWeekly, sessionFable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gaugeOnly: "Gauge Only"
        case .session: "Session %"
        case .sessionWeekly: "Session + Weekly"
        case .sessionFable: "Session + Fable"
        }
    }
}

/// Settings > General (S-040 to S-042). Test runs keep their own copy.
@MainActor
@Observable
final class Preferences {
    private let defaults: UserDefaults

    var menuBarStyle: MenuBarStyle { didSet { defaults.set(menuBarStyle.rawValue, forKey: "menuBar.style") } }
    /// Minutes between limit fetches: 1, 5, or 15.
    var refreshMinutes: Int { didSet { defaults.set(refreshMinutes, forKey: "limits.refreshMinutes"); onRefreshChange?() } }
    static let refreshChoices = [1, 5, 15]

    /// Called when the refresh interval changes, so the timer restarts.
    var onRefreshChange: (() -> Void)?

    /// Mirrors the login item macOS has, not a stored copy (S-041).
    private(set) var openAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var loginError: String?

    init() {
        let tests = Store.isOverridden
        if tests { UserDefaults.standard.removePersistentDomain(forName: "app.kakeibo.mac.prefs-tests") }
        defaults = tests ? UserDefaults(suiteName: "app.kakeibo.mac.prefs-tests")! : .standard
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menuBar.style") ?? "") ?? .session
        let minutes = defaults.integer(forKey: "limits.refreshMinutes")
        refreshMinutes = Self.refreshChoices.contains(minutes) ? minutes : 5
    }

    /// Registers or removes the login item. Never in test runs.
    func setOpenAtLogin(_ on: Bool) {
        loginError = nil
        guard !Store.isOverridden else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Unable to change the login item: \(error.localizedDescription)"
        }
        refreshLoginState()
    }

    func refreshLoginState() {
        openAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            loginError = "Allow Kakeibo in System Settings > General > Login Items."
        }
    }
}
