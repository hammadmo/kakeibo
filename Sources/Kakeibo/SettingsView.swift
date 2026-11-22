import AppKit
import SwiftUI

/// The Settings window (Command-Comma), drawn with the design kit like
/// Hachibu's: a hidden title bar, text tabs with a gold underline, and cards
/// of rows. A plain Window, not a Settings scene, so the title bar can hide.
struct SettingsView: View {
    static let windowID = "settings"
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            KitTabBar(tabs: SettingsTab.allCases.map { (id: $0, title: $0.title) }, selection: $model.settingsTab,
                      label: "Settings sections")
                .padding(.top, Metric.titleBarInset)
                .padding(.bottom, Space.sm)
            KitDivider()
            Group {
                switch model.settingsTab {
                case .general: GeneralSettings()
                case .about: AboutSettings()
                }
            }
            .padding(Space.xxl)
            .fixedSize(horizontal: false, vertical: true)
        }
        .kitWindow(width: Metric.settingsWidth)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .about: "About"
        }
    }
}

/// Where Kakeibo's numbers come from. The choices in M4 and M5 (Alerts,
/// menu bar, refresh, login item) join this tab.
struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            SettingsSection(title: "Limits") {
                SettingsRow(title: "Claude Code login",
                            detail: "Kakeibo reads the login Claude Code keeps in your Keychain to fetch your limits.") {
                    StatusPill(text: loginText, tone: loginTone)
                }
                SettingsRow(title: "Refresh", detail: "Limits every 5 minutes, logs every minute.") {
                    Button("Refresh Now") { Task { await model.refreshNow() } }
                        .buttonStyle(.kit(.secondary))
                        .fixedSize()
                }
            }
            SettingsSection(title: "Usage") {
                SettingsRow(title: "Claude Code logs", detail: "~/.claude/projects, read only.") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([UsageService.root])
                    }
                    .buttonStyle(.kit(.ghost))
                    .fixedSize()
                }
            }
        }
    }

    private var loginText: String {
        switch model.limits.status {
        case .ok, .offline: "Signed in"
        case .signedOut: "Signed out"
        case .expired: "Expired"
        case .loading: "Checking…"
        }
    }

    private var loginTone: StatusPill.Tone {
        switch model.limits.status {
        case .ok, .offline: .good
        case .signedOut, .expired: .warning
        case .loading: .idle
        }
    }
}

struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            SealMark(size: Metric.sealSize * 2)
            VStack(spacing: Space.xs) {
                Text("Kakeibo").kitType(.title).foregroundStyle(Ink.text)
                Text("Version \(version)").kitType(.meta).foregroundStyle(Ink.textSoft)
            }
            Text("A ledger of your Claude usage. Kakeibo reads Claude Code's logs on this Mac and asks Anthropic only for your plan limits. Costs are estimates at API prices.")
                .kitType(.body)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
