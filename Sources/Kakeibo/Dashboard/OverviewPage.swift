import Charts
import KakeiboKit
import SwiftData
import SwiftUI

/// The Dashboard's first page: where the tokens went in the range.
struct OverviewPage: View {
    @Environment(AppModel.self) private var model
    @State private var data: DashboardData

    /// `data` lets snapshot mode render the page already loaded.
    init(data: DashboardData = DashboardData()) {
        _data = State(initialValue: data)
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Space.xl) {
            UsageCard()
            if data.loaded && !data.hasAnyActivity {
                // S-010: no logs at all.
                KitEmptyState(title: "No Claude Code Activity Yet",
                              message: "Kakeibo reads the logs in ~/.claude/projects.")
            } else {
                RangePicker(range: $model.dashboardRange)
                HStack(alignment: .top, spacing: Space.lg) {
                    ThisWeekCard(this: data.thisWeek, last: data.lastWeekSoFar)
                    ModelSplitCard(families: data.families)
                }
                TokensByDayCard(days: data.byDay, range: model.dashboardRange)
            }
            if let breakdown = model.limits.current?.breakdown {
                WeeklyBySurfaceCard(breakdown: breakdown, weekly: model.limits.current?.weekly)
            }
            LimitHistoryCard(range: model.dashboardRange)
        }
        .task(id: "\(model.dashboardRange.rawValue)-\(model.usage.version)") {
            data = await model.usage.dashboard(range: model.dashboardRange)
        }
    }
}

/// "7 Days | 30 Days" (S-011): kit buttons, the chosen one selected.
struct RangePicker: View {
    @Binding var range: DashboardRange

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(DashboardRange.allCases) { option in
                Button(option.title) { range = option }
                    .buttonStyle(.kit(.secondary, selected: range == option))
                    .fixedSize()
                    .accessibilityAddTraits(range == option ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Range")
    }
}

/// A titled kit card for the Dashboard.
struct DashboardCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).kitType(.section).foregroundStyle(Ink.accentText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                accessory
            }
            VStack(alignment: .leading, spacing: Space.md) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .kitCard()
        }
    }
}

extension DashboardCard where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, accessory: { EmptyView() }, content: content)
    }
}

/// S-012: this week's Tokens and Cost against the same point last week.
struct ThisWeekCard: View {
    let this: UsageTotals
    let last: UsageTotals

    var body: some View {
        DashboardCard(title: "This week") {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(Format.tokens(this.tokens)).kitType(.gaugeNumeralSmall).foregroundStyle(Ink.text)
                Text("tokens · \(Format.cost(this.cost))").kitType(.label).foregroundStyle(Ink.textSoft)
            }
            Text(changeText).kitType(.meta).foregroundStyle(Ink.textSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var changeText: String {
        guard let change = Weeks.change(this: Double(this.tokens), last: Double(last.tokens)) else {
            return "Nothing to compare with last week"
        }
        if change == 0 { return "Same as last week" }
        return "\(change > 0 ? "↑" : "↓") \(abs(change))% vs last week"
    }
}

/// S-013: each model's share of Tokens in the range, as one split bar.
struct ModelSplitCard: View {
    let families: [(family: String, totals: UsageTotals)]

    private var total: Int { max(families.reduce(0) { $0 + $1.totals.tokens }, 1) }

    var body: some View {
        DashboardCard(title: "By model") {
            GeometryReader { geo in
                HStack(spacing: Metric.heatGap) {
                    ForEach(families, id: \.family) { entry in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Ink.series(entry.family))
                            .frame(width: max(share(entry) * (geo.size.width - gaps), 2))
                    }
                }
            }
            .frame(height: Metric.statusDot * 2)
            .accessibilityHidden(true)
            ModelLegend(entries: families.map { ($0.family, "\(Int((share($0) * 100).rounded()))%") })
        }
        .frame(maxWidth: .infinity)
    }

    private var gaps: CGFloat { CGFloat(max(families.count - 1, 0)) * Metric.heatGap }
    private func share(_ entry: (family: String, totals: UsageTotals)) -> CGFloat {
        CGFloat(entry.totals.tokens) / CGFloat(total)
    }
}

/// Swatch + name (+ value) per model, in the fixed model order.
struct ModelLegend: View {
    let entries: [(family: String, value: String?)]

    var body: some View {
        HStack(spacing: Space.md) {
            ForEach(entries, id: \.family) { entry in
                HStack(spacing: Space.xs) {
                    RoundedRectangle(cornerRadius: 2).fill(Ink.series(entry.family))
                        .frame(width: Metric.statusDot, height: Metric.statusDot)
                    Text(entry.value.map { "\(entry.family) \($0)" } ?? entry.family)
                        .kitType(.meta).foregroundStyle(Ink.textSoft)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// S-011: Tokens per day, stacked by model, with a hover readout.
struct TokensByDayCard: View {
    let days: [DashboardData.DayFamily]
    let range: DashboardRange
    @State private var selected: Date?

    private var families: [String] {
        Set(days.map(\.family)).sorted { ModelFamilies.rank($0) < ModelFamilies.rank($1) }
    }

    var body: some View {
        DashboardCard(title: "Tokens by day") {
            Chart(days) { entry in
                BarMark(x: .value("Day", entry.day, unit: .day),
                        y: .value("Tokens", entry.totals.tokens),
                        width: .ratio(0.7))
                    .foregroundStyle(by: .value("Model", entry.family))
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                if let selected, Calendar.current.isDate(entry.day, inSameDayAs: selected) {
                    RuleMark(x: .value("Day", selected, unit: .day))
                        .foregroundStyle(Ink.hairline)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            DayReadout(day: selected, entries: days.filter { Calendar.current.isDate($0.day, inSameDayAs: selected) })
                        }
                }
            }
            .chartForegroundStyleScale(domain: families, range: families.map(Ink.series))
            .chartLegend(.hidden)
            .chartXSelection(value: $selected)
            .chartXScale(domain: range.start()...Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Ink.hairline)
                    AxisValueLabel { if let n = value.as(Int.self) { Text(Format.tokens(n)).kitType(.meta).foregroundStyle(Ink.textSoft) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(Ink.textSoft)
                }
            }
            .frame(height: Metric.dashboardChartHeight)
            ModelLegend(entries: families.map { ($0, nil) })
        }
    }
}

/// The hover readout for one day: date, then Tokens and Cost per model.
private struct DayReadout: View {
    let day: Date
    let entries: [DashboardData.DayFamily]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(day.formatted(.dateTime.weekday(.abbreviated).day().month())).kitType(.labelStrong).foregroundStyle(Ink.text)
            ForEach(entries.sorted { ModelFamilies.rank($0.family) < ModelFamilies.rank($1.family) }) { entry in
                HStack(spacing: Space.xs) {
                    RoundedRectangle(cornerRadius: 2).fill(Ink.series(entry.family))
                        .frame(width: Metric.statusDot, height: Metric.statusDot)
                    Text("\(entry.family) \(Format.tokens(entry.totals.tokens)) · \(Format.cost(entry.totals.cost))")
                        .kitType(.meta).foregroundStyle(Ink.text)
                }
            }
        }
        .padding(Space.sm)
        .background(RoundedRectangle(cornerRadius: Metric.cardRadius).fill(Ink.surface))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).strokeBorder(Ink.hairline))
    }
}

/// S-015: Session and Weekly Used % over the range, with a dashed line at 100%.
struct LimitHistoryCard: View {
    let range: DashboardRange
    @Query(sort: \LimitSnapshot.takenAt) private var snapshots: [LimitSnapshot]

    private var points: [LimitSnapshot] { snapshots.filter { $0.takenAt >= range.start() } }

    var body: some View {
        DashboardCard(title: "Limit history") {
            if points.isEmpty {
                Text("Kakeibo keeps a reading every 5 minutes. They show here as they arrive.")
                    .kitType(.label).foregroundStyle(Ink.textSoft)
            } else {
                Chart {
                    RuleMark(y: .value("Limit", 100))
                        .foregroundStyle(Ink.warning)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    ForEach(points) { point in
                        LineMark(x: .value("Time", point.takenAt), y: .value("Used", point.sessionUsed),
                                 series: .value("Limit", "Session"))
                            .foregroundStyle(Ink.gauge)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        LineMark(x: .value("Time", point.takenAt), y: .value("Used", point.weeklyUsed),
                                 series: .value("Limit", "Weekly"))
                            .foregroundStyle(Ink.series("Opus"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine().foregroundStyle(Ink.hairline)
                        AxisValueLabel { if let n = value.as(Int.self) { Text("\(n)%").kitType(.meta).foregroundStyle(Ink.textSoft) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned) { _ in AxisValueLabel().foregroundStyle(Ink.textSoft) }
                }
                .frame(height: Metric.dashboardChartHeight)
                HStack(spacing: Space.md) {
                    legend("Session", Ink.gauge)
                    legend("Weekly", Ink.series("Opus"))
                }
            }
        }
    }

    private func legend(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Space.xs) {
            Capsule().fill(color).frame(width: Metric.statusDot * 2, height: 2)
            Text(name).kitType(.meta).foregroundStyle(Ink.textSoft)
        }
    }
}
