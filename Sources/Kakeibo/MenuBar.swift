import AppKit
import KakeiboKit
import SwiftUI

/// What sits in the menu bar: a small open ring and the Session limit's Used %.
/// It also starts the app's work, because the label exists from launch on and
/// the Dashboard window may never open.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let limits = model.limits.current
        let session = limits?.session
        Image(nsImage: MenuBarGlyph.image(style: model.preferences.menuBarStyle, session: session.map { Used($0.used) },
                                          second: MenuBarGlyph.second(model.preferences.menuBarStyle, limits)))
            .accessibilityElement(children: .ignore)
            // Only the label reaches VoiceOver for a menu bar item, so the value goes in it.
            .accessibilityLabel(MenuBarGlyph.spoken(session))
            .help(MenuBarGlyph.tooltip(session))
            .task { Startup.run(model: model, openWindow: openWindow) }
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
    private static var slot: CGFloat {
        ceil(("100%" as NSString).size(withAttributes: [.font: font]).width)
    }
    private static let separator = " · "
    private static var separatorWidth: CGFloat {
        ceil((separator as NSString).size(withAttributes: [.font: font]).width)
    }

    /// The second number a style shows: Weekly or Fable.
    static func second(_ style: MenuBarStyle, _ limits: Limits?) -> Used? {
        switch style {
        case .sessionWeekly: limits?.weekly.map { Used($0.used) }
        case .sessionFable: limits?.fable.map { Used($0.used) }
        default: nil
        }
    }

    /// The ring (Session) and, by style, no number, Session, or Session and a
    /// second limit. Each style keeps one width whatever the numbers are.
    static func image(style: MenuBarStyle = .session, session: Used?, second: Used? = nil) -> NSImage {
        let texts: [Used?] = switch style {
        case .gaugeOnly: []
        case .session: [session]
        case .sessionWeekly, .sessionFable: [session, second]
        }
        let warning = ([session] + texts).contains { $0?.isAlmostReached ?? false }
        let textWidth = texts.isEmpty ? 0 : CGFloat(texts.count) * slot + CGFloat(texts.count - 1) * separatorWidth
        let size = NSSize(width: ring + (texts.isEmpty ? 0 : gap + textWidth), height: height)
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

            // The brush: clockwise from 12 o'clock.
            if let session, session.percent > 0 {
                let sweep = 360 * session.percent / 100
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
                arc.lineWidth = 2.6
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }

            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let y = (height - font.pointSize - 3) / 2
            func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: attributes).width }
            // The first number ends at its slot's right edge and the second starts
            // right after the dot, so they read as a pair; the image width never changes.
            let firstEnd = ring + gap + slot
            if let first = texts.first {
                let text = first?.label ?? "–"
                (text as NSString).draw(at: NSPoint(x: firstEnd - width(text), y: y), withAttributes: attributes)
            }
            if texts.count > 1 {
                (separator as NSString).draw(at: NSPoint(x: firstEnd, y: y), withAttributes: attributes)
                let text = texts[1]?.label ?? "–"
                (text as NSString).draw(at: NSPoint(x: firstEnd + separatorWidth, y: y), withAttributes: attributes)
            }
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
    /// Kept for agent commands that open a window (`kakeibo open`).
    static var openWindow: OpenWindowAction?

    static func run(model: AppModel, openWindow: OpenWindowAction) {
        guard !started, !CommandLine.arguments.contains("--test-alert") else { return }
        started = true
        self.openWindow = openWindow
        // The agent CLI and MCP server reach the running app through this socket.
        AgentRouter.model = model
        AgentSocket.listen { await AgentRouter.handle($0) }
        SeedData.insertIfRequested(into: model)
        SeedData.writeLogs()
        SelfTest.runIfRequested(model: model)
        LimitsProbe.runIfRequested(model: model)
        if !SelfTest.requested && !LimitsProbe.requested { model.start() }
        Snapshot.runIfRequested(model: model, openWindow: openWindow)
    }
}
