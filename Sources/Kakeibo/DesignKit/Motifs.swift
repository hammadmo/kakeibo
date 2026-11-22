import SwiftUI

// The two motifs from the app icon, for quiet decoration. Both are hidden
// from VoiceOver and never carry meaning.

/// Seigaiha, the pattern of calm seas: rows of overlapping scales, each
/// three concentric arcs, rising from the bottom edge and higher on the
/// leading side, like a shoreline. Stroke it with `Ink.relief`.
nonisolated struct Seigaiha: Shape {
    /// The radius of one scale.
    var radius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = radius
        let rows = Int((rect.height / (r / 2)).rounded(.up)) + 2
        let columns = Int((rect.width / (2 * r)).rounded(.up)) + 2
        for row in 0..<rows {
            let cy = rect.maxY + r * 0.25 - CGFloat(row) * r / 2
            let shift: CGFloat = row % 2 == 1 ? r : 0
            for column in -1..<columns {
                let cx = rect.minX + CGFloat(column) * 2 * r + shift
                let along = min(max((cx - rect.minX) / max(rect.width, 1), 0), 1)
                let reach = rect.height * (1 - 0.65 * along)
                if cy - r * 0.5 < rect.maxY - reach { continue }
                // Each arc shows only where the rows below do not cover it.
                let covers = [CGPoint(x: cx - r, y: cy + r / 2), CGPoint(x: cx + r, y: cy + r / 2),
                              CGPoint(x: cx, y: cy + r)]
                for share in [1.0, 0.7, 0.4] {
                    let rho = r * CGFloat(share)
                    var drawing = false
                    let steps = 40
                    for step in 0...steps {
                        let angle = Double.pi + Double.pi * Double(step) / Double(steps)
                        let point = CGPoint(x: cx + rho * CGFloat(cos(angle)), y: cy + rho * CGFloat(sin(angle)))
                        let seen = point.y <= rect.maxY && covers.allSatisfy {
                            hypot(point.x - $0.x, point.y - $0.y) >= r - 0.25
                        }
                        if seen {
                            if drawing { path.addLine(to: point) } else { path.move(to: point) }
                        }
                        drawing = seen
                    }
                }
            }
        }
        return path
    }
}

/// Ume, the plum blossom: five round petals around a heart, with stamens.
/// One flower, or a small sprig of two flowers and loose petals.
struct UmeBlossom: View {
    enum Arrangement { case single, sprig }

    var size: CGFloat = 16
    var arrangement: Arrangement = .single

    var body: some View {
        ZStack {
            UmeShape(part: .petals, arrangement: arrangement).fill(Ink.accent)
            UmeShape(part: .stamens, arrangement: arrangement).fill(Ink.seal)
        }
        .frame(width: arrangement == .sprig ? size * 3 : size, height: arrangement == .sprig ? size * 2 : size)
        .accessibilityHidden(true)
    }
}

nonisolated struct UmeShape: Shape {
    enum Part { case petals, stamens }

    var part: Part
    var arrangement: UmeBlossom.Arrangement

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch arrangement {
        case .single:
            flower(&path, center: CGPoint(x: rect.midX, y: rect.midY), size: min(rect.width, rect.height), turn: -18)
        case .sprig:
            // Laid out on a 3 x 2 box: a large flower, a small one, three loose petals.
            let unit = rect.height / 2
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit) }
            flower(&path, center: at(2.2, 0.75), size: unit * 1.2, turn: -18)
            flower(&path, center: at(1.05, 1.35), size: unit * 0.7, turn: 12)
            if part == .petals {
                for (x, y, turn) in [(0.3, 0.6, 30.0), (1.5, 0.3, -40.0), (2.85, 1.7, 70.0)] {
                    loosePetal(&path, center: at(CGFloat(x), CGFloat(y)), size: unit * 0.16, turn: turn)
                }
            }
        }
        return path
    }

    private func circle(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat) {
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func flower(_ path: inout Path, center: CGPoint, size: CGFloat, turn: Double) {
        for index in 0..<5 {
            let petal = (turn + Double(index) * 72) * Double.pi / 180
            let stamen = (turn + 36 + Double(index) * 72) * Double.pi / 180
            switch part {
            case .petals:
                circle(&path, CGPoint(x: center.x + size * 0.287 * CGFloat(cos(petal)),
                                      y: center.y + size * 0.287 * CGFloat(sin(petal))), size * 0.213)
            case .stamens:
                circle(&path, CGPoint(x: center.x + size * 0.139 * CGFloat(cos(stamen)),
                                      y: center.y + size * 0.139 * CGFloat(sin(stamen))), size * 0.035)
            }
        }
        circle(&path, center, part == .petals ? size * 0.167 : size * 0.046)
    }

    private func loosePetal(_ path: inout Path, center: CGPoint, size: CGFloat, turn: Double) {
        let box = CGRect(x: -size, y: -size * 0.62, width: size * 2, height: size * 1.24)
        let move = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(turn * Double.pi / 180))
        path.addPath(Path(ellipseIn: box).applying(move))
    }
}
