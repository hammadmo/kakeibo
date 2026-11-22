import Foundation

/// Numbers as Kakeibo writes them.
public enum Format {
    /// 980 → "980", 12_400 → "12.4 k", 1_240_000 → "1.24 M", 2_300_000_000 → "2.3 B".
    public static func tokens(_ n: Int) -> String {
        let value = Double(n)
        switch value {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return trimmed(value / 1_000) + " k"
        case ..<1_000_000_000: return trimmed(value / 1_000_000) + " M"
        default: return trimmed(value / 1_000_000_000) + " B"
        }
    }

    /// For VoiceOver: "1.24 million tokens".
    public static func spokenTokens(_ n: Int) -> String {
        tokens(n).replacingOccurrences(of: " k", with: " thousand")
            .replacingOccurrences(of: " M", with: " million")
            .replacingOccurrences(of: " B", with: " billion") + " tokens"
    }

    /// 18.4 → "$18.40", 0.004 → "<$0.01", 0 → "$0".
    public static func cost(_ usd: Double) -> String {
        if usd == 0 { return "$0" }
        if usd < 0.01 { return "<$0.01" }
        if usd >= 1_000 { return "$" + String(format: "%.0f", usd).withThousands }
        return String(format: "$%.2f", usd)
    }

    /// Three significant digits, no trailing zeros: 1.24, 12.4, 124.
    private static func trimmed(_ v: Double) -> String {
        let text = v >= 100 ? String(format: "%.0f", v) : v >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v)
        guard text.contains(".") else { return text }
        var t = text
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }
}

private extension String {
    var withThousands: String {
        var out = ""
        for (i, c) in reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(",") }
            out.append(c)
        }
        return String(out.reversed())
    }
}
