import AppKit
import SwiftUI

/// The menu bar popover's own window, so a button in it can close it before
/// opening the Dashboard, Settings, or another app.
@MainActor
enum PopoverWindow {
    private static weak var window: NSWindow?

    static func close() {
        window?.close()
    }

    /// Remembers the window the popover is shown in. Only the real popover
    /// uses it, so the snapshot preview window never closes itself.
    struct Tracker: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { TrackingView() }
        func updateNSView(_ nsView: NSView, context: Context) {}

        private final class TrackingView: NSView {
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                if let window { PopoverWindow.window = window }
            }
        }
    }
}
