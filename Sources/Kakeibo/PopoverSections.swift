import AppKit
import KakeiboKit
import SwiftUI

/// S-006: Today's Tokens and their Cost at API prices.
struct TodayCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let usage = model.usage
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Today").kitType(.label).foregroundStyle(Ink.textSoft)
                if usage.today.replies > 0 {
                    Text("\(Format.tokens(usage.today.tokens)) tokens")
                        .kitType(.numeral)
                        .foregroundStyle(Ink.text)
                } else {
                    Text(usage.hasRead ? "No Claude Code activity today" : "Reading Claude Code logs…")
                        .kitType(.label)
                        .foregroundStyle(Ink.textSoft)
                }
            }
            Spacer(minLength: Space.sm)
            if usage.today.replies > 0 {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    Text(Format.cost(usage.today.cost))
                        .kitType(.numeral)
                        .foregroundStyle(Ink.accentText)
                    Text("Estimated at API prices")
                        .kitType(.meta)
                        .foregroundStyle(Ink.textSoft)
                }
                .help("Estimated from Claude Code logs at API prices. Your plan is not billed this amount.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kitCard()
        .accessibilityElement(children: .combine)
    }
}

/// S-007: the Projects that used the most Tokens Today.
struct TodayByProject: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    static let shown = 3

    var body: some View {
        let rows = model.usage.todayByProject
        let total = max(model.usage.today.tokens, 1)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(rows.prefix(Self.shown)) { row in
                    ProjectRowView(row: row, share: Double(row.totals.tokens) / Double(total))
                }
                if rows.count > Self.shown {
                    Button("+\(rows.count - Self.shown) more") {
                        model.sidebar = .projects
                        Dashboard.open(openWindow)
                    }
                    .buttonStyle(.plain)
                    .kitType(.meta)
                    .foregroundStyle(Ink.accentText)
                    .help("Show every Project in the Dashboard")
                }
            }
        }
    }
}

private struct ProjectRowView: View {
    let row: UsageService.ProjectRow
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.sm) {
                Text(row.name)
                    .kitType(.label)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.id)
                Spacer(minLength: Space.sm)
                Text(Format.tokens(row.totals.tokens))
                    .kitType(.meta)
                    .foregroundStyle(Ink.textSoft)
            }
            GeometryReader { geo in
                Capsule().fill(Ink.hairline)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Ink.gauge).frame(width: max(geo.size.width * share, 2))
                    }
            }
            .frame(height: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(Format.spokenTokens(row.totals.tokens)), \(Int((share * 100).rounded())) percent of today")
    }
}

/// S-008 and S-044: when the limits were read, Refresh, and the app's commands.
struct PopoverFooter: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var refreshing = false

    var body: some View {
        VStack(spacing: Space.sm) {
            HStack {
                if let updated = model.limits.updatedAt {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .kitType(.meta)
                        .foregroundStyle(Ink.textSoft)
                }
                Spacer()
                if refreshing || model.usage.isReading {
                    ProgressView().controlSize(.small)
                        .frame(width: Metric.iconSize, height: Metric.iconSize)
                } else {
                    Button {
                        Task { refreshing = true; await model.refreshNow(); refreshing = false }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: Metric.iconSize, weight: .light))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Ink.textSoft)
                    .keyboardShortcut("r")
                    .help("Fetch limits and read new logs now (⌘R)")
                    .accessibilityLabel("Refresh")
                }
            }
            Rectangle().fill(Ink.hairline).frame(height: Metric.hairline)
            HStack(spacing: 0) {
                Button("Dashboard…") { Dashboard.open(openWindow) }
                    .keyboardShortcut("d")
                    .help("Open the Dashboard (⌘D)")
                Button("Settings…") { openWindow(id: SettingsView.windowID); NSApp.activate() }
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit Kakeibo") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.kit(.ghost))
        }
    }
}

extension Dashboard {
    @MainActor
    static func open(_ openWindow: OpenWindowAction) {
        openWindow(id: windowID)
        NSApp.activate()
    }
}
