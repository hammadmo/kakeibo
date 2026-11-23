import KakeiboKit
import SwiftUI

/// S-053: the first thing on the Dashboard. Every limit as a gauge with when
/// it resets, then today's numbers in one row.
struct UsageCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let limits = model.limits.current
        DashboardCard(title: "Usage") {
            if let updated = model.limits.updatedAt {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .kitType(.meta).foregroundStyle(Ink.textSoft)
            }
        } content: {
            TimelineView(.everyMinute) { context in
                HStack(alignment: .top, spacing: Space.lg) {
                    LimitColumn(name: "Session", window: limits?.session, now: context.date)
                    LimitColumn(name: "Weekly", window: limits?.weekly, now: context.date)
                    if limits?.fable != nil || limits == nil {
                        LimitColumn(name: "Fable", window: limits?.fable, now: context.date)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            if limits == nil, model.limits.status == .signedOut || model.limits.status == .expired {
                Text("Sign in to Claude Code to see your limits: run claude in Terminal, then /login.")
                    .kitType(.label).foregroundStyle(Ink.textSoft)
                    .frame(maxWidth: .infinity)
            }
            KitDivider()
            TodayNumbers()
        }
    }
}

/// One limit: its gauge, name, Used %, and when it resets (relative and exact).
private struct LimitColumn: View {
    let name: String
    let window: LimitWindow?
    let now: Date

    var body: some View {
        let used = window.map { Used($0.used) }
        let warning = used?.isAlmostReached ?? false
        VStack(spacing: Space.xs) {
            EnsoGauge(percent: used.map { Int($0.percent.rounded()) }, tone: warning ? .warning : .normal,
                      size: Metric.gaugeSmall, showsSeal: warning, label: "\(name) limit",
                      resets: ResetText.spoken(window?.resets, now: now))
            Text(name).kitType(.status).foregroundStyle(Ink.text)
            if warning {
                Text("Almost reached").kitType(.labelStrong).foregroundStyle(Ink.warning)
            }
            Text(window.map { ResetText.short($0.resets, now: now) } ?? " ")
                .kitType(.meta).foregroundStyle(Ink.textSoft)
            // The exact time under a countdown; a reset days away already shows it.
            Text(window?.resets.flatMap { resets in
                resets.timeIntervalSince(now) < 24 * 3600 ? resets.formatted(.dateTime.weekday(.abbreviated).hour().minute()) : nil
            } ?? " ")
                .kitType(.meta).foregroundStyle(Ink.textSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) limit")
        .accessibilityValue(used.map { "\(Int($0.percent.rounded())) percent used, \(ResetText.spoken(window?.resets, now: now) ?? "")" } ?? "no reading")
    }
}

/// Today's numbers: Tokens, estimated Cost, replies, Projects, live sessions.
private struct TodayNumbers: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let usage = model.usage
        HStack(alignment: .top, spacing: Space.lg) {
            stat("Today", "\(Format.tokens(usage.today.tokens)) tokens")
            stat("Est. cost", Format.cost(usage.today.cost), accent: true)
                .help("Estimated from Claude Code logs at API prices. Your plan is not billed this amount.")
            stat("Replies", "\(usage.today.replies)")
            stat("Projects", "\(usage.todayByProject.count)")
            stat("Live now", "\(usage.live.count)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(Format.spokenTokens(usage.today.tokens)), estimated \(Format.cost(usage.today.cost)), \(usage.today.replies) replies, \(usage.todayByProject.count) projects, \(usage.live.count) live sessions")
    }

    private func stat(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).kitType(.meta).foregroundStyle(Ink.textSoft)
            Text(value).kitType(.numeral).foregroundStyle(accent ? Ink.accentText : Ink.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
