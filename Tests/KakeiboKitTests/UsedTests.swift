import Testing
@testable import KakeiboKit

@Test("Clamp and label", arguments: [
    (42.4, "42%"),
    (-5, "0%"),
    (130, "100%"),
])
func label(_ input: Double, expected: String) {
    #expect(Used(input).label == expected)
}

@Test func almostReachedStartsAt90() {
    #expect(!Used(89.9).isAlmostReached)
    #expect(Used(90).isAlmostReached)
}
