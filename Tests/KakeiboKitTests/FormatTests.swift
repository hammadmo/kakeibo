import Testing
@testable import KakeiboKit

@Test("Tokens", arguments: [
    (980, "980"), (12_400, "12.4 k"), (1_240_000, "1.24 M"), (1_000_000, "1 M"), (480_000_000, "480 M"), (2_300_000_000, "2.3 B"),
])
func tokens(_ n: Int, expected: String) {
    #expect(Format.tokens(n) == expected)
}

@Test("Cost", arguments: [(18.4, "$18.40"), (0.004, "<$0.01"), (0, "$0"), (1234.5, "$1,234")])
func cost(_ usd: Double, expected: String) {
    #expect(Format.cost(usd) == expected)
}

@Test func spoken() {
    #expect(Format.spokenTokens(412_000) == "412 thousand tokens")
}
