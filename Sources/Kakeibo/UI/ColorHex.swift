import AppKit
import SwiftUI

// Color helpers for the design kit's tokens (DesignKit/Tokens.swift).

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A color with a light and a dark value: Color(light: 0x0064D2, dark: 0x7CC0FF).
    /// Add the two high-contrast values for Increase Contrast; they default
    /// to the normal ones.
    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                               .accessibilityHighContrastDarkAqua]) {
            case .darkAqua: NSColor(hex: dark)
            case .accessibilityHighContrastAqua: NSColor(hex: highContrastLight ?? light)
            case .accessibilityHighContrastDarkAqua: NSColor(hex: highContrastDark ?? dark)
            default: NSColor(hex: light)
            }
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
