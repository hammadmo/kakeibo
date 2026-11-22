import AppKit
import KakeiboKit
import SwiftUI

/// What sits in the menu bar: a small open ring and the Session limit's Used %.
/// It also starts the app's work, because the label exists from launch on and
/// the Dashboard window may never open.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let session = model.limits.current?.session
        Image(nsImage: MenuBarGlyph.image(used: session.map { Used($0.used) }))
            .accessibilityElement(children: .ignore)
            // Only the label reaches VoiceOver for a menu bar item, so the value goes in it.
            .accessibilityLabel(MenuBarGlyph.spoken(session))
            .help(MenuBarGlyph.tooltip(session))
            .task { Startup.run(model: model, openWindow: openWindow, openSettings: openSettings) }
    }
}

/// The menu bar picture, drawn by hand so its width never changes (no other
/// icon jumps as the number moves) and so it can turn vermilion at 90%.
/// Below 90% it is a template image: the menu bar tints it like system icons.
enum MenuBarGlyph {
    static let height: CGFloat = 18
    private static let ring = Metric.menuBarGauge
    private static let gap: CGFloat = 4
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    /// Room for "100%", so 9% and 100% take the same space.
    private static var textWidth: CGFloat {
        ceil(("100%" as NSString).size(withAttributes: [.font: font]).width)
    }

    static func image(used: Used?) -> NSImage {
        let warning = used?.isAlmostReached ?? false
        let size = NSSize(width: ring + gap + textWidth, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            let color: NSColor = warning ? NSColor(hex: 0xE0685C) : .black
            let center = NSPoint(x: ring / 2, y: height / 2)
            let radius = ring / 2 - 1.5

            // The tick ring: a faint full circle, so 0% still reads as a gauge.
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 1
            color.withAlphaComponent(warning ? 0.35 : 0.3).setStroke()
            track.stroke()

            // The brush: clockwise from 12 o'clock, thick where it lands.
            if let used, used.percent > 0 {
                let sweep = 360 * used.percent / 100
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
                arc.lineWidth = 2.6
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }

            let text = used?.label ?? "–"
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let textSize = (text as NSString).size(withAttributes: attributes)
            // Right-aligned in its fixed slot, so the digits stay put.
            (text as NSString).draw(at: NSPoint(x: size.width - textSize.width, y: (height - textSize.height) / 2),
                                    withAttributes: attributes)
            return true
        }
        image.isTemplate = !warning
        return image
    }

    static func tooltip(_ session: LimitWindow?) -> String {
        guard let session else { return "Kakeibo: no limits yet" }
        return "Kakeibo: Session \(Used(session.used).label) used, \(ResetText.short(session.resets).lowercased())"
    }

    static func spoken(_ session: LimitWindow?) -> String {
        guard let session else { return "Kakeibo, no limits yet" }
        let warning = Used(session.used).isAlmostReached ? ", almost reached" : ""
        return "Kakeibo, Session limit \(Int(session.used.rounded())) percent used\(warning)"
    }
}

/// Work that starts with the app: test modes, the limits timer, snapshots.
@MainActor
enum Startup {
    private static var started = false

    static func run(model: AppModel, openWindow: OpenWindowAction, openSettings: OpenSettingsAction) {
        guard !started else { return }
        started = true
        SeedData.insertIfRequested(into: model)
        SelfTest.runIfRequested(model: model)
        LimitsProbe.runIfRequested(model: model)
        if !SelfTest.requested && !LimitsProbe.requested { model.limits.start() }
        Snapshot.runIfRequested(model: model, openWindow: openWindow, openSettings: openSettings)
    }
}
