import AppKit
import SwiftData
import SwiftUI

// Kakeibo
//   Kakeibo                      the app
//   APP_STORE=<file> Kakeibo     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> Kakeibo   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 Kakeibo           fill an empty /tmp store with sample items (tools/snap.sh)
//   Kakeibo --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   Kakeibo --test-alert         ask for notification permission, send one Alert, quit
//   Kakeibo --probe-limits       fetch the real limits once, print window keys and Used %, quit
//   APP_LIMITS=<fixture> Kakeibo use fixture limits: normal, warning, signedout, offline, empty
//   APP_GRID=1 Kakeibo           draw the 8 pt grid and the layout probes over the window

struct KakeiboApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(container: Store.makeContainer())

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(model)
                .background(PopoverWindow.Tracker())
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window(Dashboard.title, id: Dashboard.windowID) {
            ContentView()
                .environment(model)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        }
        .modelContainer(model.container)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        // Test runs open it, so they start even if the menu bar has no room
        // for the item (its label never draws, so its task never runs).
        .defaultLaunchBehavior(Store.isOverridden ? .presented : .suppressed)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) { SettingsCommand() }
        }

        // Opens only in snapshot runs: the popover in a plain window, so it can be captured.
        Window(PopoverPreview.title, id: PopoverPreview.windowID) {
            PopoverView()
                .environment(model)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // A plain window, not a Settings scene: SwiftUI gives a Settings scene
        // a system title bar that cannot be hidden.
        Window("Kakeibo Settings", id: SettingsView.windowID) {
            SettingsView()
                .environment(model)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// Settings… (Command-Comma) opens the kit Settings window.
struct SettingsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") { openWindow(id: SettingsView.windowID); NSApp.activate() }
            .keyboardShortcut(",")
    }
}

enum Dashboard {
    static let title = "Kakeibo"
    static let windowID = "dashboard"
}

enum PopoverPreview {
    static let title = "Kakeibo Popover"
    static let windowID = "popover-preview"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kakeibo --test-alert: ask for permission, send one Alert, quit.
        if CommandLine.arguments.contains("--test-alert") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            Task { @MainActor in
                let sent = await AlertService().sendTest()
                print(sent ? "TEST ALERT sent" : "TEST ALERT not allowed: turn on notifications for Kakeibo in System Settings")
                try? await Task.sleep(for: .seconds(2))
                NSApp.terminate(nil)
            }
            return
        }
        // A menu bar app: no Dock icon until the Dashboard or Settings opens.
        // Test runs stay regular so their windows can be captured.
        if Store.isOverridden {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        } else {
            NSApp.setActivationPolicy(.accessory)
            ActivationPolicy.watch()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Shows Kakeibo in the Dock and the app switcher while a real window is open,
/// and hides it again when the last one closes.
@MainActor
enum ActivationPolicy {
    static func watch() {
        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { update(closing: nil) }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            let closing = (note.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated { update(closing: closing) }
        }
    }

    /// A real window has a title bar; the popover's panel does not.
    private static func update(closing: ObjectIdentifier?) {
        let open = NSApp.windows.contains {
            $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel) && ObjectIdentifier($0) != closing
        }
        let wanted: NSApplication.ActivationPolicy = open ? .regular : .accessory
        guard NSApp.activationPolicy() != wanted else { return }
        NSApp.setActivationPolicy(wanted)
        if open { NSApp.activate() }
    }
}

/// Where the data lives: ~/Library/Application Support/Kakeibo/Kakeibo.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Kakeibo", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Kakeibo.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: LimitSnapshot.self, Summary.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
