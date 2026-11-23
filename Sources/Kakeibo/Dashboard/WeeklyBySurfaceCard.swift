import KakeiboKit
import SwiftUI

/// S-017: how much of the Weekly limit went to each surface (Claude Code,
/// Chats, Cowork, Other), from the limits response. Hidden without one.
struct WeeklyBySurfaceCard: View {
    let breakdown: SurfaceBreakdown
    let weekly: LimitWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly limit by surface").kitType(.section).foregroundStyle(Ink.accentText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let weekly {
                    Text("\(Used(weekly.used).label) used").kitType(.meta).foregroundStyle(Ink.textSoft)
                }
            }
            VStack(alignment: .leading, spacing: Space.md) {
                ForEach(breakdown.rows) { row in
                    SurfaceRow(row: row)
                }
                if let caption {
                    Text(caption).kitType(.meta).foregroundStyle(Ink.textSoft)
                }
            }
            .kitCard()
        }
    }

    private var caption: String? {
        var parts: [String] = []
        if let asOf = breakdown.asOf {
            parts.append("As of \(asOf.formatted(date: .omitted, time: .shortened))")
        }
        if let started = breakdown.weekStarted {
            parts.append("week started \(started.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct SurfaceRow: View {
    let row: SurfaceBreakdown.Row

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).kitType(.body).foregroundStyle(Ink.text)
                Spacer(minLength: Space.sm)
                Text("\(percent(row.shareOfLimit)) of limit · \(percent(row.shareOfUse)) of use")
                    .kitType(.meta)
                    .foregroundStyle(Ink.textSoft)
            }
            GeometryReader { geo in
                Capsule().fill(Ink.hairline)
                    .overlay(alignment: .leading) {
                        if row.shareOfLimit > 0 {
                            Capsule().fill(Ink.gauge)
                                .frame(width: max(geo.size.width * min(row.shareOfLimit, 100) / 100, 2))
                        }
                    }
            }
            .frame(height: Metric.sliderTrack * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(Int(row.shareOfLimit.rounded())) percent of the Weekly limit, \(Int(row.shareOfUse.rounded())) percent of your use this week")
    }

    private func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }
}
