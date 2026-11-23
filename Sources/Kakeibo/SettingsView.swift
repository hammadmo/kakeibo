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
                case .alerts: AlertSettings()
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
    case general, alerts, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .alerts: "Alerts"
        case .about: "About"
        }
    }
}

/// Where Kakeibo's numbers come from. The choices in M5 (menu bar,
/// refresh, login item) join this tab.
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

/// S-033: which Alerts Kakeibo sends, and when the daily one goes out.
struct AlertSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var alerts = model.alerts
        VStack(alignment: .leading, spacing: Space.xl) {
            if alerts.permission == .denied {
                SettingsSection(title: nil) {
                    SettingsRow(title: "Notifications are off for Kakeibo",
                                detail: "Turn them on in System Settings to get these Alerts.") {
                        Button("Open Notifications…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.kit(.secondary))
                        .fixedSize()
                    }
                }
            }
            SettingsSection(title: "Alerts") {
                SettingsRow(title: "Limit almost reached",
                            detail: "At 80% and 90% of the Session, Weekly, and Fable limits, once each until it resets.") {
                    Toggle("Limit almost reached", isOn: $alerts.limitAlerts).toggleStyle(.kit).labelsHidden()
                }
                SettingsRow(title: "Limit reset", detail: "When a limit you pushed past 80% goes back to 0%.") {
                    Toggle("Limit reset", isOn: $alerts.resetAlerts).toggleStyle(.kit).labelsHidden()
                }
                SettingsRow(title: "Daily numbers", detail: "Today's tokens, cost, and busiest Project, on days with activity.") {
                    HStack(spacing: Space.md) {
                        DatePicker("Time", selection: $alerts.dailyTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .disabled(!alerts.dailyAlert)
                            .fixedSize()
                        Toggle("Daily numbers", isOn: $alerts.dailyAlert).toggleStyle(.kit).labelsHidden()
                    }
                }
            }
        }
        .task { await model.alerts.refreshPermission() }
    }
}
