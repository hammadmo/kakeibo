import Foundation

/// How much of a limit is used. Logic lives in this library so tests can run
/// it without the app. Put the log parser, price table, and formatters here too.
public struct Used: Equatable, Sendable {
    /// 0...100, clamped.
    public let percent: Double

    public init(_ percent: Double) {
        self.percent = min(max(percent, 0), 100)
    }

    /// At 90% or more the Gauge turns vermilion and the Seal shows.
    public var isAlmostReached: Bool { percent >= 90 }

    /// "42%"
    public var label: String { "\(Int(percent.rounded()))%" }
}
