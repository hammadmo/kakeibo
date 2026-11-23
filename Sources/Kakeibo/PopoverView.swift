import AppKit
import KakeiboKit
import SwiftUI

/// The popover under the menu bar item: three Gauges with when each Resets,
/// Today's Tokens (S-006), Today by Project (S-007), and the footer (S-008).
struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let limits = model.limits
        VStack(spacing: Space.lg) {
            TimelineView(.everyMinute) { context in
                GaugesSection(limits: limits.current, status: limits.status, now: context.date)
            }
            StatusLine(status: limits.status, updatedAt: limits.updatedAt)
            TodayCard()
            LiveNow()
            TodayByProject()
            PopoverFooter()
        }
        .padding(Space.lg)
        .frame(width: Metric.popoverWidth)
        .background(Ink.surface)
    }
}

private struct GaugesSection: View {
    let limits: Limits?
    let status: LimitsService.Status
    let now: Date

    var body: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.sm) {
                gauge("Session", limits?.session, size: Metric.gaugeSize)
                caption("Session", limits?.session, strong: true)
            }
            if let warning = almostReached {
                Label("\(warning) limit almost reached", systemImage: "exclamationmark.triangle")
                    .kitType(.labelStrong)
                    .foregroundStyle(Ink.warning)
            }
            HStack(alignment: .top, spacing: Space.xl) {
                small("Weekly", limits?.weekly)
                if limits?.fable != nil || limits == nil { small("Fable", limits?.fable) }
            }
        }
    }

    private var almostReached: String? {
        [("Session", limits?.session), ("Weekly", limits?.weekly), ("Fable", limits?.fable)]
            .first { ($0.1?.used ?? 0) >= 90 }?.0
    }

    private func small(_ name: String, _ window: LimitWindow?) -> some View {
        VStack(spacing: Space.xs) {
            gauge(name, window, size: Metric.gaugeSmall)
            caption(name, window, strong: false)
        }
    }

    private func gauge(_ name: String, _ window: LimitWindow?, size: CGFloat) -> some View {
        let used = window.map { Used($0.used) }
        let warning = used?.isAlmostReached ?? false
        return EnsoGauge(percent: used.map { Int($0.percent.rounded()) }, tone: warning ? .warning : .normal,
                         size: size, showsSeal: warning, label: "\(name) limit",
                         resets: ResetText.spoken(window?.resets, now: now))
    }

    private func caption(_ name: String, _ window: LimitWindow?, strong: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .kitType(strong ? .status : .labelStrong)
                .foregroundStyle(Ink.text)
            Text(window.map { ResetText.short($0.resets, now: now) } ?? " ")
                .kitType(.meta)
                .foregroundStyle(Ink.textSoft)
        }
        .accessibilityHidden(true) // the Gauge reads the same words
    }
}

/// One line under the Gauges for every state that isn't a fresh reading.
private struct StatusLine: View {
    let status: LimitsService.Status
    let updatedAt: Date?

    var body: some View {
        switch status {
        case .ok:
            EmptyView()
        case .loading:
            note("Fetching limits…")
        case .signedOut, .expired:
            VStack(spacing: Space.sm) {
                note(status == .expired
                     ? "Your Claude Code login expired. Run claude in Terminal to sign in again."
                     : "Sign in to Claude Code to see your limits: run claude in Terminal, then /login.")
                Button("Open Terminal") {
                    PopoverWindow.close()
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                }
                    .buttonStyle(.kit(.secondary))
                    .fixedSize()
            }
        case .offline:
            note(updatedAt.map { "Showing limits from \($0.formatted(date: .omitted, time: .shortened)). Unable to reach Anthropic." }
                 ?? "Unable to reach Anthropic.")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .kitType(.label)
            .foregroundStyle(Ink.textSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
