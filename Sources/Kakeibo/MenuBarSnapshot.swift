import AppKit
import KakeiboKit

/// menubar-light.png and menubar-dark.png: the menu bar item at 9%, 42%, and
/// 92% on a strip in the menu bar's colors, drawn with MenuBarGlyph itself.
@MainActor
enum MenuBarSnapshot {
    static func render(to dir: String) {
        // One row per style (S-040): no reading, 9%, 42%, 92%; second limit 18%, 63%, 95%.
        let samples: [(Double?, Double?)] = [(nil, nil), (9, 18), (42, 63), (92, 18), (42, 95)]
        for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let rows = MenuBarStyle.allCases.map { style in
                samples.map { MenuBarGlyph.image(style: style, session: $0.0.map(Used.init), second: $0.1.map(Used.init)) }
            }
            let pad: CGFloat = 12
            let width = rows.map { $0.reduce(pad) { $0 + $1.size.width + pad } }.max() ?? 100
            let size = NSSize(width: width, height: CGFloat(rows.count) * 24)
            let strip = NSImage(size: size, flipped: false) { rect in
                (mode == "light" ? NSColor(white: 0.93, alpha: 1) : NSColor(white: 0.16, alpha: 1)).setFill()
                rect.fill()
                let ink: NSColor = mode == "light" ? .black : .white
                for (row, images) in rows.enumerated() {
                var x = pad
                let rowY = size.height - CGFloat(row + 1) * 24
                for image in images {
                    let frame = NSRect(x: x, y: rowY + (24 - image.size.height) / 2,
                                       width: image.size.width, height: image.size.height)
                    if image.isTemplate {
                        // Tint like the menu bar does: the template's alpha in the bar's ink.
                        let tinted = NSImage(size: image.size, flipped: false) { r in
                            image.draw(in: r)
                            ink.set()
                            r.fill(using: .sourceAtop)
                            return true
                        }
                        tinted.draw(in: frame)
                    } else {
                        image.draw(in: frame)
                    }
                    x += image.size.width + pad
                }
                }
                return true
            }
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance { strip.draw(at: .zero, from: .zero, operation: .copy, fraction: 1) }
            NSGraphicsContext.restoreGraphicsState()
            let path = "\(dir)/menubar-\(mode).png"
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path)")
        }
    }
}
