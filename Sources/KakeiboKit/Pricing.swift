import Foundation

/// API prices in USD per million tokens (claude-api skill, cached 2026-11-03).
/// Cost in Kakeibo is an estimate at these prices; plans are not billed per token.
public struct Price: Equatable, Sendable {
    public let input: Double
    public let output: Double
    /// Share of `input` a cache read costs: 0.1 on most models.
    public let readRatio: Double

    public var cacheWrite5m: Double { input * 1.25 }
    public var cacheWrite1h: Double { input * 2 }
    public var cacheRead: Double { input * readRatio }

    public init(input: Double, output: Double, readRatio: Double = 0.1) {
        self.input = input
        self.output = output
        self.readRatio = readRatio
    }
}

public enum Pricing {
    /// Longest prefix first, so "claude-opus-5-5" wins over "claude-opus-5".
    static let table: [(prefix: String, price: Price)] = [
        ("claude-fable-5-2", Price(input: 8, output: 40, readRatio: 0.025)),
        ("claude-mythos-5-2", Price(input: 8, output: 40, readRatio: 0.025)),
        ("claude-fable-5-1", Price(input: 10, output: 50, readRatio: 0.025)),
        ("claude-mythos-5-1", Price(input: 10, output: 50, readRatio: 0.025)),
        ("claude-fable-5", Price(input: 10, output: 50)),
        ("claude-opus-5-5", Price(input: 4, output: 20, readRatio: 0.05)),
        ("claude-opus-5", Price(input: 5, output: 25)),
        ("claude-opus-4-8", Price(input: 5, output: 25)),
        ("claude-opus-4-7", Price(input: 5, output: 25)),
        ("claude-opus-4-6", Price(input: 5, output: 25)),
        ("claude-opus-4-5", Price(input: 5, output: 25)),
        ("claude-sonnet-5-5", Price(input: 2, output: 10, readRatio: 0.05)),
        ("claude-sonnet-5", Price(input: 2, output: 10)),
        ("claude-sonnet-4", Price(input: 3, output: 15)),
        ("claude-haiku-5-5", Price(input: 0.1, output: 0.5)),
        ("claude-haiku-4-5", Price(input: 1, output: 5)),
    ]

    /// nil for a model not in the table: its tokens count, its cost is $0.
    public static func price(for model: String) -> Price? {
        table.first { model.hasPrefix($0.prefix) }?.price
    }

    /// The family shown in charts: "Fable", "Opus", "Sonnet", "Haiku", or "Other".
    public static func family(of model: String) -> String {
        for name in ["fable", "mythos", "opus", "sonnet", "haiku"] where model.contains(name) {
            return name == "mythos" ? "Fable" : name.capitalized
        }
        return "Other"
    }
}
