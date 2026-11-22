import AppKit
import KakeiboKit

/// menubar-light.png and menubar-dark.png: the menu bar item at 9%, 42%, and
/// 92% on a strip in the menu bar's colors, drawn with MenuBarGlyph itself.
@MainActor
enum MenuBarSnapshot {
    static func render(to dir: String) {
        let samples: [Double?] = [nil, 9, 42, 92, 100]
        for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let images = samples.map { MenuBarGlyph.image(used: $0.map(Used.init)) }
            let pad: CGFloat = 12
            let width = images.reduce(pad) { $0 + $1.size.width + pad }
            let size = NSSize(width: width, height: 24)
            let strip = NSImage(size: size, flipped: false) { rect in
                (mode == "light" ? NSColor(white: 0.93, alpha: 1) : NSColor(white: 0.16, alpha: 1)).setFill()
                rect.fill()
                let ink: NSColor = mode == "light" ? .black : .white
                var x = pad
                for image in images {
                    let frame = NSRect(x: x, y: (size.height - image.size.height) / 2,
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
