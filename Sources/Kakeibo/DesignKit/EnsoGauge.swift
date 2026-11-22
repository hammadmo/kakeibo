import SwiftUI

/// The Gauge: an ink brush circle left open. The stroke runs clockwise from
/// 12 o'clock to the share of a limit Used; the gap is what is left.
/// Dust drifts from the brush tip into the gap.
struct EnsoGauge: View {
    enum Tone { case normal, warning }

    /// 0 to 100. nil means no reading.
    var percent: Int?
    /// The limit, marked with a dot on the tick ring. nil or 100 hides it.
    var limit: Int?
    var tone: Tone = .normal
    var size: CGFloat = Metric.gaugeSize
    /// The Seal shows only when a limit is almost reached (90% or more).
    var showsSeal = false
    /// VoiceOver label: "Session limit".
    var label = "Limit"
    /// VoiceOver tail: "resets in 2 hours 14 minutes".
    var resets: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scale: CGFloat { size / Metric.gaugeSize }
    private var isSmall: Bool { size < Metric.gaugeSize }
    private var ringColor: Color { tone == .warning ? Ink.warning : Ink.gauge }

    var body: some View {
        let tick = Metric.tickLength * scale
        let stroke = Metric.gaugeStroke * scale
        let level = Double(percent ?? 0) / 100
        ZStack {
            TickRing(count: Metric.tickCount, length: tick)
                .stroke(Ink.tick, lineWidth: Metric.hairline)
            if let limit, limit < 100, percent != nil {
                RingDot(progress: Double(limit) / 100, inset: tick / 2, radius: Metric.limitDot * scale)
                    .fill(Ink.seal)
            }
            Group {
                BrushDust(progress: level, thickness: stroke)
                    .fill(ringColor.opacity(0.8))
                BrushArc(progress: level, thickness: stroke)
                    .fill(ringColor)
            }
            .padding(tick + stroke * 0.75)
            .animation(reduceMotion ? nil : Motion.gauge, value: percent)
            Text(percent.map(String.init) ?? "–")
                .kitType(isSmall ? .gaugeNumeralSmall : .gaugeNumeral)
                .foregroundStyle(percent == nil ? Ink.textSoft : tone == .warning ? Ink.warning : Ink.text)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if showsSeal {
                SealMark(size: isSmall ? Metric.sealSmall : Metric.sealSize)
                    .rotationEffect(.degrees(-5))
                    .padding(tick + stroke)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityText)
    }

    private var accessibilityText: String {
        guard let percent else { return "No reading" }
        var parts = ["\(percent)% used"]
        if tone == .warning { parts.append("almost reached") }
        if let resets { parts.append(resets) }
        return parts.joined(separator: ", ")
    }
}

/// The Seal: a carved stamp with 家 (house), from 家計簿 kakeibo. Decorative.
struct SealMark: View {
    var size: CGFloat = Metric.sealSize

    var body: some View {
        RoundedRectangle(cornerRadius: Metric.sealRadius, style: .continuous)
            .fill(Ink.seal)
            .frame(width: size, height: size)
            .overlay {
                Text("家")
                    .kitType(size < Metric.sealSize ? .sealSmall : .seal)
                    .foregroundStyle(Ink.onSeal)
            }
            .accessibilityHidden(true)
    }
}

/// The geometry of one brush stroke around a circle. The same recipe draws
/// the app icon (tools/draw_icon.py): a pool of ink where the brush lands, a
/// hand's waver, a slow drift inward, and dry bristle streaks at the end.
nonisolated struct Brush {
    var center: CGPoint
    /// Centerline radius.
    var radius: CGFloat
    /// The band's width at its fullest.
    var thickness: CGFloat
    /// How much of the circle the stroke covers, 0 to 1.
    var end: Double

    /// A small, smooth, repeatable waver between -1 and 1.
    static func wobble(_ u: Double, _ seed: Double) -> Double {
        sin(u * 23 + seed) * 0.6 + sin(u * 57 + seed * 2.3) * 0.3 + sin(u * 131 + seed * 5.1) * 0.1
    }

    /// A hand never draws a true circle: it wavers, and pulls inward late.
    func centerline(_ u: Double) -> CGFloat {
        let t = u / max(end, 0.001)
        let drift = 0.04 * pow(max(t - 0.55, 0), 1.5)
        return radius * CGFloat(1 + 0.012 * Self.wobble(u, 1) - drift)
    }

    /// A point `offset` outward from the centerline, `u` of the way round.
    func point(_ u: Double, _ offset: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + u * 2 * Double.pi
        let r = centerline(u) + offset
        return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
    }

    /// Adds a closed band between two edges. A hole runs the other way
    /// round, so it cuts out of the stroke under the nonzero fill rule.
    func band(_ path: inout Path, from u0: Double, to u1: Double, steps: Int, hole: Bool = false,
              outer: (Double) -> CGFloat, inner: (Double) -> CGFloat) {
        var points: [CGPoint] = []
        points.reserveCapacity(steps * 2 + 2)
        for step in 0...steps {
            let u = u0 + (u1 - u0) * Double(step) / Double(steps)
            points.append(point(u, outer(u)))
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let u = u0 + (u1 - u0) * Double(step) / Double(steps)
            points.append(point(u, inner(u)))
        }
        if hole { points.reverse() }
        path.addLines(points)
        path.closeSubpath()
    }

    func blob(_ path: inout Path, at u: Double, offset: CGFloat, radius r: CGFloat) {
        let middle = point(u, offset)
        let steps = 32
        var points: [CGPoint] = []
        for step in 0..<steps {
            let k = Double(step) / Double(steps)
            let rr = r * CGFloat(1 + 0.08 * Self.wobble(k, 7))
            points.append(CGPoint(x: middle.x + rr * CGFloat(cos(2 * Double.pi * k)),
                                  y: middle.y + rr * CGFloat(sin(2 * Double.pi * k))))
        }
        path.addLines(points)
        path.closeSubpath()
    }

    func stroke() -> Path {
        var path = Path()
        let full = thickness
        let bodyEnd = end * 0.875

        // The body: heavy where the brush lands, even through the middle, thinning late.
        func width(_ u: Double) -> CGFloat {
            let t = u / end
            let land = 1.12 - 0.12 * min(t / 0.125, 1)
            let thin = 1 - 0.28 * pow(max((t - 0.625) / 0.25, 0), 1.4)
            return full / 2 * CGFloat(land * thin)
        }
        band(&path, from: min(0.006, bodyEnd / 2), to: bodyEnd, steps: max(Int(end * 300), 24),
             outer: { width($0) * CGFloat(1 + 0.07 * Self.wobble($0, 2)) },
             inner: { -width($0) * CGFloat(1 + 0.07 * Self.wobble($0, 4)) })

        // The pool of ink where the brush first touches down.
        blob(&path, at: min(0.008, end / 2), offset: full * 0.04, radius: full * 0.6)
        blob(&path, at: 0, offset: -full * 0.3, radius: full * 0.3)

        guard end > 0.15 else { return path }

        // Dry-brush streaks: the bristles separate and run out of ink one by one.
        let strands: [(lane: Double, stop: Double, share: Double)] = [
            (-0.40, 0.94, 0.17), (-0.20, 1.0, 0.20), (0.0, 0.97, 0.16), (0.19, 0.99, 0.19), (0.39, 0.925, 0.15),
        ]
        let start = end * 0.75
        for strand in strands {
            let stop = end * strand.stop
            func half(_ u: Double) -> CGFloat {
                let t = (u - start) / (stop - start)
                return max(full * CGFloat(strand.share / 2 * (1 - pow(t, 1.6))), 0.2)
            }
            func lane(_ u: Double) -> CGFloat {
                let t = max((u - start) / (end - start), 0)
                return full * CGFloat(strand.lane * (1 - 0.25 * t))
            }
            band(&path, from: start, to: stop, steps: 60,
                 outer: { lane($0) + half($0) * CGFloat(1 + 0.1 * Self.wobble($0, strand.lane * 9)) },
                 inner: { lane($0) - half($0) })
        }

        // Flying white: slivers where the paper shows through the stroke.
        let slivers: [(lane: Double, from: Double, to: Double, fat: Double)] = [
            (-0.18, 0.50, 0.75, 0.045), (0.22, 0.575, 0.775, 0.035), (0.02, 0.625, 0.75, 0.03),
        ]
        for sliver in slivers {
            let u0 = end * sliver.from, u1 = end * sliver.to
            func half(_ u: Double) -> CGFloat {
                let t = min(max((u - u0) / (u1 - u0), 0), 1)
                return full * CGFloat(sliver.fat * pow(sin(Double.pi * t), 0.7))
            }
            band(&path, from: u0, to: u1, steps: 40, hole: true,
                 outer: { full * CGFloat(sliver.lane) + half($0) },
                 inner: { full * CGFloat(sliver.lane) - half($0) })
        }
        return path
    }

    /// Specks drifting from the brush tip into the gap: dense near the tip,
    /// thinning out, never further than a fifth of the circle.
    func dust() -> Path {
        var path = Path()
        guard end > 0.05, end < 0.97 else { return path }
        let span = min(1 - end + 0.02, 0.22)
        let count = 44
        for index in 0..<count {
            let k = Double(index) / Double(count - 1)
            let u = end - 0.01 + span * pow(k, 0.85) + 0.012 * Self.wobble(k, 11)
            let spread = thickness * CGFloat(0.55 + 0.5 * k)
            let offset = spread * CGFloat(Self.wobble(k * 3.1, 13 + Double(index)))
            let grain = (0.16 - 0.1 * k) * (0.5 + 0.5 * abs(Self.wobble(k * 5, 17 + Double(index))))
            let r = max(thickness * CGFloat(grain), 0.5)
            let middle = point(u, offset)
            path.addEllipse(in: CGRect(x: middle.x - r, y: middle.y - r, width: r * 2, height: r * 2))
        }
        return path
    }
}

/// The brush stroke of the gauge. Filled, not stroked.
nonisolated struct BrushArc: Shape {
    /// 0 to 1 of the full circle.
    var progress: Double
    var thickness: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let p = min(max(progress, 0), 1)
        guard p > 0.004 else { return Path() }
        return Brush(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
                     thickness: thickness, end: p).stroke()
    }
}

/// The dust in the gap after the brush tip.
nonisolated struct BrushDust: Shape {
    var progress: Double
    var thickness: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Brush(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
              thickness: thickness, end: min(max(progress, 0), 1)).dust()
    }
}

/// Short radial ticks around the edge, like a dial.
nonisolated struct TickRing: Shape {
    var count: Int
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * Double.pi
            let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
            path.move(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
            path.addLine(to: CGPoint(x: center.x + dx * (outer - length), y: center.y + dy * (outer - length)))
        }
        return path
    }
}

/// A dot on the edge of a circle, at `progress` clockwise from 12 o'clock.
nonisolated struct RingDot: Shape {
    var progress: Double
    var inset: CGFloat
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle = -Double.pi / 2 + progress * 2 * Double.pi
        let r = min(rect.width, rect.height) / 2 - inset
        let center = CGPoint(x: rect.midX + r * CGFloat(cos(angle)), y: rect.midY + r * CGFloat(sin(angle)))
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2))
    }
}
