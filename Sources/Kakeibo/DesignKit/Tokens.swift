import AppKit
import SwiftUI

// Kakeibo's design kit, taken from Hachibu's (same family). The spec is design/KIT.md.
// Layer 1 (Pigment) is raw color. Layer 2 (Ink) is meaning. Parts read only
// Ink, KitType, Metric, Motion, and KitIcon.

/// Layer 1: raw colors. Only this file reads Pigment.
private enum Pigment {
    static let paper: UInt32 = 0xF4EFE6
    static let paperDeep: UInt32 = 0xECE5D7
    static let paperLine: UInt32 = 0xDDD3C0
    static let paperTick: UInt32 = 0xCFC3AB
    static let paperRelief: UInt32 = 0xE3D8C3
    static let ink: UInt32 = 0x1F1B16
    static let inkSoft: UInt32 = 0x6F6558

    static let lacquer: UInt32 = 0x100D0C
    static let lacquerRaised: UInt32 = 0x1A1613
    static let lacquerLine: UInt32 = 0x2A2218
    static let lacquerTick: UInt32 = 0x3F3320
    static let lacquerRelief: UInt32 = 0x2B2115
    static let cream: UInt32 = 0xEADFC8
    static let creamSoft: UInt32 = 0x9A8D75

    static let gold: UInt32 = 0xC9A45C
    static let goldMid: UInt32 = 0xA07C2C
    static let goldDeep: UInt32 = 0x7F6119
    static let goldDim: UInt32 = 0x6B5935

    static let seal: UInt32 = 0xB4322A
    static let sealBright: UInt32 = 0xE0685C
    static let sealPaper: UInt32 = 0xF4E9D6
}

/// Layer 2: meaning, with a light (paper and ink) and a dark (lacquer and
/// gold) value each.
enum Ink {
    static let surface = Color(light: Pigment.paper, dark: Pigment.lacquer)
    /// The surface for AppKit, so a window's own background matches the kit.
    static let surfaceNS = NSColor(name: nil) { appearance in
        NSColor(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? Pigment.lacquer : Pigment.paper)
    }
    static let raised = Color(light: Pigment.paperDeep, dark: Pigment.lacquerRaised)
    static let hairline = Color(light: Pigment.paperLine, dark: Pigment.lacquerLine)
    static let tick = Color(light: Pigment.paperTick, dark: Pigment.lacquerTick)
    /// Tone-on-tone decoration, like relief in lacquer: the wave pattern.
    static let relief = Color(light: Pigment.paperRelief, dark: Pigment.lacquerRelief)

    static let text = Color(light: Pigment.ink, dark: Pigment.cream)
    static let textSoft = Color(light: Pigment.inkSoft, dark: Pigment.creamSoft)

    /// The brush ring, the slider fill, and chart lines.
    static let gauge = Color(light: Pigment.ink, dark: Pigment.gold)
    static let accent = Color(light: Pigment.goldMid, dark: Pigment.gold)
    static let accentText = Color(light: Pigment.goldDeep, dark: Pigment.gold)

    static let fill = Color(light: Pigment.ink, dark: Pigment.gold)
    static let onFill = Color(light: Pigment.paper, dark: Pigment.lacquer)
    static let outline = Color(light: Pigment.ink, dark: Pigment.goldDim)
    static let outlineText = Color(light: Pigment.ink, dark: Pigment.gold)
    /// Dims a window behind a dialog.
    static let scrim = Color(light: Pigment.paper, dark: Pigment.lacquer).opacity(0.82)
    static let wash = Color(light: Pigment.ink, dark: Pigment.gold).opacity(0.1)

    static let seal = Color(hex: Pigment.seal)
    static let onSeal = Color(hex: Pigment.sealPaper)
    static let warning = Color(light: Pigment.seal, dark: Pigment.sealBright)
    static let warningWash = Color(hex: Pigment.seal).opacity(0.16)
}

/// Layer 3: type roles. Numerals are serif; everything else is the system sans.
enum KitType {
    case gaugeNumeral, gaugeNumeralSmall, numeral, title, status, body, label, labelStrong, section, meta, seal, sealSmall

    var font: Font {
        switch self {
        case .gaugeNumeral: .system(size: 44, weight: .regular, design: .serif).monospacedDigit()
        case .gaugeNumeralSmall: .system(size: 28, weight: .regular, design: .serif).monospacedDigit()
        case .numeral: .system(size: 15, weight: .regular, design: .serif).monospacedDigit()
        case .title: .system(size: 22, weight: .regular, design: .serif)
        case .status: .system(size: 14, weight: .medium)
        case .body: .system(size: 13)
        case .section: .system(size: 11, weight: .medium)
        case .label: .system(size: 12)
        case .labelStrong: .system(size: 12, weight: .medium)
        case .meta: .system(size: 11).monospacedDigit()
        case .seal: .system(size: 11, weight: .medium)
        case .sealSmall: .system(size: 8, weight: .medium)
        }
    }
}

extension View {
    func kitType(_ type: KitType) -> some View { font(type.font) }
}

/// Layer 3: sizes.
enum Metric {
    static let popoverWidth: CGFloat = 320
    static let menuBarGauge: CGFloat = 14
    static let gaugeSize: CGFloat = 160
    static let gaugeSmall: CGFloat = 112
    static let gaugeStroke: CGFloat = 13
    static let tickCount = 60
    static let tickLength: CGFloat = 4
    static let limitDot: CGFloat = 3
    static let sealSize: CGFloat = 20
    static let sealSmall: CGFloat = 12
    static let sealRadius: CGFloat = 3
    static let buttonHeight: CGFloat = 32
    static let statusHeight: CGFloat = 36
    static let buttonRadius: CGFloat = 4
    static let cardRadius: CGFloat = 8
    static let dialogWidth: CGFloat = 336
    static let sliderHeight: CGFloat = 24
    static let sliderTrack: CGFloat = 2
    static let sliderThumb: CGFloat = 12
    static let sparkHeight: CGFloat = 48
    static let hairline: CGFloat = 1
    static let focusRing: CGFloat = 2
    static let iconSize: CGFloat = 14
    static let settingsWidth: CGFloat = 520
    static let historyWidth: CGFloat = 760
    static let historyEmptyHeight: CGFloat = 320
    static let chartHeight: CGFloat = 120
    static let chartDot: CGFloat = 3
    static let titleBarInset: CGFloat = 36
    static let tabHeight: CGFloat = 36
    static let tabUnderline: CGFloat = 2
    static let rowHeight: CGFloat = 44
    static let toggleWidth: CGFloat = 36
    static let toggleHeight: CGFloat = 20
    static let toggleThumb: CGFloat = 14
    static let statusDot: CGFloat = 8
    static let appIconSize: CGFloat = 96
    static let waveBand: CGFloat = 64
    static let waveRadius: CGFloat = 24
    static let blossom: CGFloat = 16
}

/// Layer 3: motion, named by intent.
enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
    static let gauge = Animation.easeInOut(duration: 0.6)
}

/// Every part computes one state. The gallery forces it, so hover and
/// pressed show up in a snapshot.
enum PartState: String, CaseIterable {
    case rest, hover, pressed, selected, focused, disabled
}

extension EnvironmentValues {
    @Entry var forcedPartState: PartState?
}
