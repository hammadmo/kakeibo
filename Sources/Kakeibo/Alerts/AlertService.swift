import Foundation
import Observation
import UserNotifications
import KakeiboKit

/// Alerts (S-030 to S-033): limit almost reached, limit reset, and the daily
/// numbers. The rules are `AlertRules` and `DailyAlert` in KakeiboKit.
@MainActor
@Observable
final class AlertService {
    /// Test runs keep their own settings and never post real notifications.
    private let defaults: UserDefaults = Store.isOverridden ? UserDefaults(suiteName: "app.kakeibo.mac.tests")! : .standard

    var limitAlerts: Bool { didSet { defaults.set(limitAlerts, forKey: "alerts.limits"); turnedOn(limitAlerts) } }
    var resetAlerts: Bool { didSet { defaults.set(resetAlerts, forKey: "alerts.resets"); turnedOn(resetAlerts) } }
    var dailyAlert: Bool { didSet { defaults.set(dailyAlert, forKey: "alerts.daily"); turnedOn(dailyAlert) } }
    /// Minutes after midnight for the daily Alert; 21:00 by default.
    var dailyMinutes: Int { didSet { defaults.set(dailyMinutes, forKey: "alerts.dailyMinutes") } }

    /// What macOS allows; shown in Settings > Alerts.
    private(set) var permission: UNAuthorizationStatus = .notDetermined
    /// Every Alert sent in a test run, in order (self-test reads it).
    private(set) var sent: [AlertEvent] = []

    private var states: [String: LimitAlertState]
    private var lastDaily: Date? { didSet { defaults.set(lastDaily, forKey: "alerts.lastDaily") } }
    private var timer: Task<Void, Never>?

    init() {
        let d = Store.isOverridden ? UserDefaults(suiteName: "app.kakeibo.mac.tests")! : UserDefaults.standard
        if Store.isOverridden { d.removePersistentDomain(forName: "app.kakeibo.mac.tests") }
        limitAlerts = d.object(forKey: "alerts.limits") as? Bool ?? true
        resetAlerts = d.object(forKey: "alerts.resets") as? Bool ?? true
        dailyAlert = d.object(forKey: "alerts.daily") as? Bool ?? true
        dailyMinutes = d.object(forKey: "alerts.dailyMinutes") as? Int ?? 21 * 60
        lastDaily = d.object(forKey: "alerts.lastDaily") as? Date
        states = (d.data(forKey: "alerts.states")).flatMap { try? JSONDecoder().decode([String: LimitAlertState].self, from: $0) } ?? [:]
    }

    var dailyTime: Date {
        get { Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(dailyMinutes) * 60) }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }

    // MARK: Limits (S-030, S-031)

    /// Called with every new limits reading.
    func observe(_ limits: Limits) {
        for (name, window) in [("Session", limits.session), ("Weekly", limits.weekly), ("Fable", limits.fable)] {
            guard let window else { continue }
            let out = AlertRules.evaluate(limit: name, state: states[name] ?? LimitAlertState(), window: window)
            states[name] = out.state
            for event in out.events {
                switch event {
                case .almostReached where limitAlerts, .reset where resetAlerts: send(event)
                default: break
                }
            }
        }
        defaults.set(try? JSONEncoder().encode(states), forKey: "alerts.states")
    }

    // MARK: Daily (S-032)

    /// Checks the daily Alert every minute.
    func start(usage: UsageService) {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkDaily(usage: usage)
                try? await Task.sleep(for: .seconds(60))
            }
        }
        Task { await refreshPermission() }
    }

    func checkDaily(usage: UsageService, now: Date = .now) {
        guard dailyAlert, usage.hasRead,
              DailyAlert.shouldFire(now: now, hour: dailyMinutes / 60, minute: dailyMinutes % 60, lastFired: lastDaily,
                                    hasActivity: usage.today.replies > 0)
        else { return }
        lastDaily = now
        send(.daily(tokens: usage.today.tokens, cost: usage.today.cost, topProject: usage.todayByProject.first?.name))
    }

    // MARK: Notifications

    /// Settings > Alerts > Send Test Alert, and `Kakeibo --test-alert`: asks for
    /// permission if needed and sends one Alert now. Returns whether it went out.
    @discardableResult
    func sendTest() async -> Bool {
        guard await requestPermissionIfNeeded() else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Kakeibo Alerts are on"
        content.body = "You'll hear from Kakeibo at 80% and 90% of a limit, when it resets, and with the daily numbers."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        return (try? await UNUserNotificationCenter.current().add(request)) != nil
    }

    private func send(_ event: AlertEvent) {
        guard !Store.isOverridden else { sent.append(event); return }
        Task {
            // Asked the first time an Alert is due, never at launch.
            guard await requestPermissionIfNeeded() else { return }
            let content = UNMutableNotificationContent()
            content.title = event.title()
            content.sound = event.identifier == "daily" ? nil : .default
            let request = UNNotificationRequest(identifier: event.identifier, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Turning a toggle on asks for permission once, so the first Alert isn't lost.
    private func turnedOn(_ on: Bool) {
        guard on, !Store.isOverridden else { return }
        Task { _ = await requestPermissionIfNeeded() }
    }

    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        await refreshPermission()
        return permission == .authorized || permission == .provisional
    }

    func refreshPermission() async {
        guard !Store.isOverridden else { return }
        permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
