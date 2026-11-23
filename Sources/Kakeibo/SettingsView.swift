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
        let preferences = model.preferences
        VStack(alignment: .leading, spacing: Space.xl) {
            SettingsSection(title: "Menu Bar") {
                SettingsRow(title: "Show", detail: "The ring always shows the Session limit.") {
                    KitMenu(selection: preferences.menuBarStyle.title,
                            options: MenuBarStyle.allCases.map { style in (style.title, { preferences.menuBarStyle = style }) })
                        .accessibilityLabel("Menu bar shows")
                }
                SettingsRow(title: "Open at Login", detail: preferences.loginError) {
                    Toggle("Open at Login", isOn: Binding(get: { preferences.openAtLogin },
                                                          set: { preferences.setOpenAtLogin($0) }))
                        .toggleStyle(.kit).labelsHidden()
                }
            }
            SettingsSection(title: "Limits") {
                SettingsRow(title: "Claude Code login",
                            detail: "Kakeibo reads the login Claude Code keeps in your Keychain to fetch your limits.") {
                    StatusPill(text: loginText, tone: loginTone)
                }
                SettingsRow(title: "Refresh every", detail: "Logs are read every minute.") {
                    HStack(spacing: Space.md) {
                        KitMenu(selection: minutes(preferences.refreshMinutes),
                                options: Preferences.refreshChoices.map { m in (minutes(m), { preferences.refreshMinutes = m }) })
                            .accessibilityLabel("Refresh limits every")
                        Button("Refresh Now") { Task { await model.refreshNow() } }
                            .buttonStyle(.kit(.secondary))
                            .fixedSize()
                    }
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
        .onAppear { preferences.refreshLoginState() }
    }

    private func minutes(_ m: Int) -> String { m == 1 ? "1 minute" : "\(m) minutes" }

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
    @Environment(AppModel.self) private var model

    var body: some View {
        let preferences = model.preferences
        VStack(spacing: Space.xl) {
            VStack(spacing: Space.lg) {
                SealMark(size: Metric.sealSize * 2)
                VStack(spacing: Space.xs) {
                    Text("Kakeibo").kitType(.title).foregroundStyle(Ink.text)
                    Text("Version \(Updates.installedVersion)").kitType(.meta).foregroundStyle(Ink.textSoft)
                }
                Text("A ledger of your Claude usage. Kakeibo reads Claude Code's logs on this Mac and asks Anthropic only for your plan limits. Costs are estimates at API prices.")
                    .kitType(.body)
                    .foregroundStyle(Ink.textSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            // Snapshot runs show it too, so the tab can be checked; no updater runs there.
            if Updates.canUpdate || Snapshot.isRunning {
                SettingsSection(title: "Updates") {
                    SettingsRow(title: "Check for updates automatically",
                                detail: "Once a day. Kakeibo reads its update feed on GitHub and sends nothing about your Mac.") {
                        Toggle("Check for updates automatically",
                               isOn: Binding(get: { preferences.checksForUpdates }, set: { preferences.checksForUpdates = $0 }))
                            .toggleStyle(.kit).labelsHidden()
                    }
                    SettingsRow(title: "Check now", detail: nil) {
                        Button("Check for Updates…") { Updates.shared.check() }
                            .buttonStyle(.kit(.secondary))
                            .fixedSize()
                    }
                }
            }
        }
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
                SettingsRow(title: "Test", detail: "Send one Alert now to check that notifications reach you.") {
                    Button("Send Test Alert") { Task { await model.alerts.sendTest() } }
                        .buttonStyle(.kit(.secondary))
                        .fixedSize()
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

/// A pull-down in the kit's look: the chosen value in gold with a chevron.
struct KitMenu: View {
    let selection: String
    let options: [(title: String, action: () -> Void)]

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { index in
                Button(options[index].title, action: options[index].action)
            }
        } label: {
            HStack(spacing: Space.xs) {
                Text(selection)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .kitType(.labelStrong)
            .foregroundStyle(Ink.accentText)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
