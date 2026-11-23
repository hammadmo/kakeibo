// Writes Icon/AppIcon.icon/Assets/ie.svg: 家 as outline paths (no text in
// icons), centered on the seal at (520, 506), inside the ensō, tilted -5 degrees like the seal.
//   swift tools/seal_glyph.swift
import CoreText
import Foundation

let font = CTFontCreateWithName("HiraMinProN-W6" as CFString, 184, nil)
var chars: [UniChar] = Array("家".utf16)
var glyphs = [CGGlyph](repeating: 0, count: chars.count)
CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
guard let outline = CTFontCreatePathForGlyph(font, glyphs[0], nil) else { fatalError("no outline for 家") }
let box = outline.boundingBox
let center = CGPoint(x: 520, y: 506)
// Flip y (font space is y-up), then center the glyph on the seal.
var transform = CGAffineTransform(translationX: center.x - box.midX, y: center.y + box.midY).scaledBy(x: 1, y: -1)
guard let placed = outline.copy(using: &transform) else { fatalError() }

var d = ""
placed.applyWithBlock { element in
    let e = element.pointee
    func p(_ i: Int) -> String { String(format: "%.1f %.1f", e.points[i].x, e.points[i].y) }
    switch e.type {
    case .moveToPoint: d += "M\(p(0)) "
    case .addLineToPoint: d += "L\(p(0)) "
    case .addQuadCurveToPoint: d += "Q\(p(0)) \(p(1)) "
    case .addCurveToPoint: d += "C\(p(0)) \(p(1)) \(p(2)) "
    case .closeSubpath: d += "Z "
    @unknown default: break
    }
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\
<path fill="#F4E9D6" fill-rule="nonzero" d="\(d.trimmingCharacters(in: .whitespaces))" transform="rotate(-5 520.0 506.0)"/></svg>
"""
try! svg.write(toFile: "Icon/AppIcon.icon/Assets/ie.svg", atomically: true, encoding: .utf8)
print("wrote Icon/AppIcon.icon/Assets/ie.svg (\(Int(box.width)) x \(Int(box.height)) pt glyph)")
