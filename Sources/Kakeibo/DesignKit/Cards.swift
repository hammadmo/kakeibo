import SwiftUI

extension View {
    /// A raised card: paper or lacquer one step up, with a hairline border.
    func kitCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
        return padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(shape.fill(Ink.raised))
            .overlay(shape.strokeBorder(Ink.hairline, lineWidth: Metric.hairline))
    }
}

/// A hairline between groups.
struct KitDivider: View {
    var body: some View {
        Rectangle().fill(Ink.hairline).frame(height: Metric.hairline)
    }
}
