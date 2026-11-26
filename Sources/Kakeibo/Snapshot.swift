import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/Kakeibo.app/Contents/MacOS/Kakeibo
/// writes <page>-light.png and <page>-dark.png for the menu bar item, the kit
/// gallery, every popover state, every Dashboard page, and every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=menubar,kit,popover,dashboard,settings picks groups.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    nonisolated(unsafe) private static var activity: NSObjectProtocol?
    /// True during a snapshot run, so parts don't pick up a hover from the pointer.
    nonisolated static let isRunning = !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty

    /// Popover pages and the fixture each one shows.
    static let popoverPages: [(page: String, fixture: String)] = [
        ("popover", "normal"), ("popover-warning", "warning"), ("popover-signedout", "signedout"),
        ("popover-offline", "offline"), ("popover-expired", "expired"), ("popover-empty", "empty"),
    ]

    static func runIfRequested(model: AppModel, openWindow: OpenWindowAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        func wants(_ group: String) -> Bool { only == nil || only!.contains(group) }
        // App Nap stretches a background app's sleeps from seconds to minutes.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Snapshots")
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1))

            if wants("menubar") { MenuBarSnapshot.render(to: dir) }
            if wants("kit") { KitGallery.render(to: dir); KitGallery.renderAlertArt(to: dir) }

            if wants("popover") {
                openWindow(id: PopoverPreview.windowID)
                try? await Task.sleep(for: .seconds(1))
                // The real popover has no traffic lights.
                for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    window(id: PopoverPreview.windowID)?.standardWindowButton(kind)?.isHidden = true
                }
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for (page, fixture) in popoverPages {
                        model.limits.applyFixture(fixture)
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(to: "\(dir)/\(page)-\(mode).png", window: window(id: PopoverPreview.windowID))
                    }
                }
                model.limits.applyFixture("normal")
                window(id: PopoverPreview.windowID)?.close()
            }

            if wants("dashboard") {
                openWindow(id: Dashboard.windowID)
                try? await Task.sleep(for: .seconds(1.5))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for page in SidebarItem.allCases {
                        model.sidebar = page
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(to: "\(dir)/\(page.rawValue)-\(mode).png", window: window(id: Dashboard.windowID))
                    }
                }
            }

            if wants("dashboard") {
                // The whole Overview page, past the fold, for the cards below the chart.
                let loaded = await model.usage.dashboard(range: model.dashboardRange)
                for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    let page = OverviewPage(data: loaded)
                        .padding(Space.xxl)
                        .frame(width: Metric.dashboardWidth)
                        .background(Ink.surface)
                        .environment(model)
                        .modelContainer(model.container)
                        .environment(\.colorScheme, mode == "dark" ? .dark : .light)
                    NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                        let renderer = ImageRenderer(content: page)
                        renderer.scale = 2
                        if let tiff = renderer.nsImage?.tiffRepresentation,
                           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                            let path = "\(dir)/overview-full-\(mode).png"
                            try? png.write(to: URL(fileURLWithPath: path))
                            print("SNAPSHOT \(path)")
                        }
                    }
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }

            if wants("settings") {
                openWindow(id: SettingsView.windowID)
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settingsWindow)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// SwiftUI names a scene's window after its id ("dashboard-AppWindow-1");
    /// titles change with the page, so they can't find a window.
    private static func window(id: String) -> NSWindow? {
        NSApp.windows.first { $0.isVisible && ($0.identifier?.rawValue.hasPrefix(id) ?? false) }
    }

    private static var settingsWindow: NSWindow? {
        window(id: SettingsView.windowID)
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow?) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        // Stage Manager shrinks a normal-level window of a background app into a
        // tilted strip thumbnail; a floating window stays full size on stage.
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...5 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                // Stage Manager can hand back its small tilted thumbnail of the
                // window. A real capture is at least the window's width in points.
                let width = NSImageRep(contentsOfFile: path)?.pixelsWide ?? 0
                if CGFloat(width) >= window.frame.width * window.backingScaleFactor * 0.95 {
                    print("SNAPSHOT \(path)")
                    return
                }
                try? FileManager.default.removeItem(atPath: path)
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
