import Foundation
import Observation
import Security
import SwiftData
import KakeiboKit

/// Fetches the plan limits with Claude Code's login and keeps the newest reading.
@MainActor
@Observable
final class LimitsService {
    enum Status: Equatable {
        case loading
        case ok
        /// No Claude Code login in the Keychain.
        case signedOut
        /// The login expired; Claude Code refreshes it next time it runs.
        case expired
        /// Network or server error; `current` is the last good reading.
        case offline(String)
    }

    private(set) var status: Status = .loading
    private(set) var current: Limits?
    private(set) var updatedAt: Date?
    private var lastFetch: Date?
    private var timer: Task<Void, Never>?
    private let container: ModelContainer?

    /// Fetch every 5 minutes; never more than once a minute.
    var interval: Duration = .seconds(300)
    static let minimumGap: TimeInterval = 60

    init(container: ModelContainer?) {
        self.container = container
        pruneOld()
        loadLast()
    }

    /// Fixture limits for snapshots and self-tests: APP_LIMITS=normal|warning|signedout|offline|empty.
    /// A test store (APP_STORE) defaults to "normal", so tests never read the Keychain.
    static var fixture: String? {
        if let name = ProcessInfo.processInfo.environment["APP_LIMITS"], !name.isEmpty { return name }
        return Store.isOverridden && !LimitsProbe.requested ? "normal" : nil
    }

    var isRunning: Bool { timer != nil }

    func start() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetch()
                try? await Task.sleep(for: self?.interval ?? .seconds(300))
            }
        }
    }

    /// Returns false when skipped because the last fetch was under a minute ago.
    @discardableResult
    func fetch(force: Bool = false) async -> Bool {
        if !force, let lastFetch, Date.now.timeIntervalSince(lastFetch) < Self.minimumGap { return false }
        lastFetch = .now
        if let fixture = Self.fixture { applyFixture(fixture); return true }

        guard var login = ClaudeLogin.read() else { status = .signedOut; return true }
        // The access token lasts about 8 hours and only Claude Code renews it, when
        // it makes a call. One tiny Haiku call renews it; then read it again.
        if login.isExpired {
            if await renewIfDue(), let renewed = ClaudeLogin.read() { login = renewed }
            if login.isExpired { status = .expired; return true }
        }
        do {
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.setValue("Bearer \(login.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 {
                // Renewed elsewhere, or not yet: renew once and try again on the next tick.
                if await renewIfDue(), ClaudeLogin.read()?.accessToken != login.accessToken { lastFetch = nil }
                status = .expired
                return true
            }
            guard code == 200 else { status = .offline("HTTP \(code)"); return true }
            apply(try Limits.decode(data))
        } catch {
            status = .offline(error.localizedDescription)
        }
        return true
    }

    /// Called with every new reading from Anthropic (the Alerts listen here).
    var onReading: ((Limits) -> Void)?

    /// When Kakeibo last asked Claude Code to renew its login.
    private var lastRenewal: Date?
    /// At most one renewal every 30 minutes (each one is a tiny Haiku call).
    static let renewalGap: TimeInterval = 1800

    /// Makes Claude Code renew its expired token with one tiny Haiku call
    /// (`ClaudeCLI.renewLogin`). Returns false when skipped (too soon).
    @discardableResult
    func renewIfDue(now: Date = .now) async -> Bool {
        if let lastRenewal, now.timeIntervalSince(lastRenewal) < Self.renewalGap { return false }
        lastRenewal = now
        await Task.detached(priority: .utility) { ClaudeCLI.renewLogin() }.value
        return true
    }

    private func apply(_ limits: Limits) {
        current = limits
        updatedAt = .now
        status = .ok
        save(limits)
        onReading?(limits)
    }

    // MARK: Storage (S-009)

    private func save(_ limits: Limits) {
        guard let context = container?.mainContext, let session = limits.session, let weekly = limits.weekly else { return }
        context.insert(LimitSnapshot(
            sessionUsed: session.used, sessionResets: session.resets ?? .now,
            weeklyUsed: weekly.used, weeklyResets: weekly.resets ?? .now,
            fableUsed: limits.fable?.used, fableResets: limits.fable?.resets))
        try? context.save()
    }

    /// Readings older than 90 days are deleted at launch.
    static let keepDays = 90

    func pruneOld(now: Date = .now) {
        guard let context = container?.mainContext else { return }
        let cutoff = now.addingTimeInterval(-Double(Self.keepDays) * 86_400)
        try? context.delete(model: LimitSnapshot.self, where: #Predicate { $0.takenAt < cutoff })
        try? context.save()
    }

    private func loadLast() {
        guard let context = container?.mainContext else { return }
        var newest = FetchDescriptor<LimitSnapshot>(sortBy: [SortDescriptor(\.takenAt, order: .reverse)])
        newest.fetchLimit = 1
        guard let last = try? context.fetch(newest).first else { return }
        current = Limits(
            session: LimitWindow(used: last.sessionUsed, resets: last.sessionResets),
            weekly: LimitWindow(used: last.weeklyUsed, resets: last.weeklyResets),
            fable: last.fableUsed.map { LimitWindow(used: $0, resets: last.fableResets) })
        updatedAt = last.takenAt
    }

    // MARK: Fixtures

    /// Also used by snapshot mode to show each state.
    func applyFixture(_ name: String) {
        let now = Date.now
        var normal = Limits(
            session: LimitWindow(used: 42, resets: now.addingTimeInterval(2 * 3600 + 14 * 60 + 30)),
            weekly: LimitWindow(used: 18, resets: now.addingTimeInterval(3 * 86_400 + 3600)),
            fable: LimitWindow(used: 63, resets: now.addingTimeInterval(3 * 86_400 + 3600)))
        // Shares of the 18% Weekly limit, like the live response's seven_day_breakdown.
        normal.breakdown = SurfaceBreakdown(
            rows: [.init(id: "claude_code", name: "Claude Code", shareOfUse: 89, shareOfLimit: 16),
                   .init(id: "chat", name: "Chats", shareOfUse: 5, shareOfLimit: 1),
                   .init(id: "cowork", name: "Cowork", shareOfUse: 6, shareOfLimit: 1),
                   .init(id: "other", name: "Other", shareOfUse: 0, shareOfLimit: 0)],
            asOf: now.addingTimeInterval(-60), weekStarted: now.addingTimeInterval(-3 * 86_400 - 82_800))
        switch name {
        case "warning":
            var warning = normal
            warning.session = LimitWindow(used: 92, resets: now.addingTimeInterval(38 * 60 + 30))
            current = warning; updatedAt = now; status = .ok
        case "expired":
            current = normal; updatedAt = now.addingTimeInterval(-3 * 3600 - 20 * 60); status = .expired
        case "signedout":
            current = nil; status = .signedOut
        case "offline":
            current = normal; updatedAt = now.addingTimeInterval(-25 * 60)
            status = .offline("The Internet connection appears to be offline.")
        case "empty":
            current = nil; status = .loading
        default:
            current = normal; updatedAt = now; status = .ok
        }
    }
}

/// Claude Code's OAuth login, read from its Keychain item. Never written or logged.
struct ClaudeLogin {
    let accessToken: String
    let expiresAt: Date?

    var isExpired: Bool { expiresAt.map { $0 < .now } ?? false }

    static func read() -> ClaudeLogin? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty,
              // An ended login stays in the item with a reason, like "time_limit".
              Self.isActive(oauth["loginEnded"])
        else { return nil }
        // 0 or missing means no known expiry (long-lived tokens); the server decides.
        let expires = (oauth["expiresAt"] as? NSNumber).flatMap { $0.doubleValue > 0 ? Date(timeIntervalSince1970: $0.doubleValue / 1000) : nil }
        return ClaudeLogin(accessToken: token, expiresAt: expires)
    }

    private static func isActive(_ loginEnded: Any?) -> Bool {
        switch loginEnded {
        case nil, is NSNull: true
        case let flag as NSNumber: !flag.boolValue
        default: false
        }
    }
}
