import AppKit
import SwiftUI

extension View {
    /// The frame every kit window shares: the paper or lacquer surface edge
    /// to edge under a hidden title bar, calm seas along the bottom edge,
    /// and a plum blossom sprig in the top trailing corner. Use it on a
    /// `Window` scene with `.windowStyle(.hiddenTitleBar)`; start the content
    /// `Metric.titleBarInset` down to clear the traffic lights.
    func kitWindow(width: CGFloat) -> some View {
        modifier(KitWindowFrame(width: width))
    }
}

private struct KitWindowFrame: ViewModifier {
    var width: CGFloat

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            Seigaiha(radius: Metric.waveRadius)
                .stroke(Ink.relief, lineWidth: Metric.hairline)
                .frame(height: Metric.waveBand)
                .accessibilityHidden(true)
        }
        .frame(width: width)
        .overlay(alignment: .topTrailing) {
            UmeBlossom(size: Metric.blossom, arrangement: .sprig)
                .opacity(0.55)
                .padding(.top, Space.sm)
                .padding(.trailing, Space.lg)
        }
        .background(Ink.surface)
        .ignoresSafeArea()
        .background(KitWindowChrome())
        .focusEffectDisabled()
        .noInitialFocus()
    }
}

/// Makes the window's own background match the kit and lets people drag it
/// by any empty area. The traffic lights stay where macOS puts them.
private struct KitWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ChromeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            NotificationCenter.default.removeObserver(self)
            apply(to: window)
            // SwiftUI finishes styling the window after this view arrives.
            DispatchQueue.main.async { [weak self] in self?.apply(to: window) }
            NotificationCenter.default.addObserver(self, selector: #selector(restyle),
                                                   name: NSWindow.didBecomeKeyNotification, object: window)
        }

        @objc private func restyle(_ note: Notification) {
            if let window { apply(to: window) }
        }

        private func apply(to window: NSWindow) {
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = Ink.surfaceNS
        }
    }
}
