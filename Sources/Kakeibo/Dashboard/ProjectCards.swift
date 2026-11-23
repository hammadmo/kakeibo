import Charts
import KakeiboKit
import SwiftUI

/// S-050: the busiest Projects in the range as cards, each with its last 14
/// days as a sparkline. Clicking one shows its activity in the heatmap.
struct ProjectCards: View {
    @Environment(AppModel.self) private var model
    let projects: [DashboardData.Project]
    @Binding var selected: String?
    @State private var lines: [String: [Int]] = [:]

    private var shown: [DashboardData.Project] { Array(projects.prefix(6)) }

    var body: some View {
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
            Text("Busiest in the last \(model.dashboardRange.rawValue) days · the line is the last 14")
                .kitType(.section).foregroundStyle(Ink.accentText)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3), spacing: Space.md) {
                ForEach(shown) { project in
                    ProjectCard(project: project, points: lines[project.id] ?? [],
                                isSelected: selected == project.id) {
                        selected = selected == project.id ? nil : project.id
                    }
                }
            }
            .task(id: "\(shown.map(\.id).joined())-\(model.usage.version)") {
                var loaded: [String: [Int]] = [:]
                for project in shown {
                    loaded[project.id] = Sparkline.points(await model.usage.heatmap(project: project.id), endingOn: .now)
                }
                lines = loaded
            }
            }
        }
    }
}

private struct ProjectCard: View {
    let project: DashboardData.Project
    let points: [Int]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(project.name).kitType(.labelStrong).foregroundStyle(Ink.text)
                    .lineLimit(1).truncationMode(.middle)
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(Format.tokens(project.totals.tokens)).kitType(.numeral).foregroundStyle(Ink.text)
                    Text(Format.cost(project.totals.cost)).kitType(.meta).foregroundStyle(Ink.textSoft)
                }
                Chart(Array(points.enumerated()), id: \.offset) { index, value in
                    AreaMark(x: .value("Day", index), y: .value("Tokens", value))
                        .foregroundStyle(Ink.accent.opacity(0.18))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", index), y: .value("Tokens", value))
                        .foregroundStyle(Ink.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: Metric.sparkHeight)
                Text(lastActive).kitType(.meta).foregroundStyle(Ink.textSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous).fill(Ink.raised))
            .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                .strokeBorder(isSelected ? Ink.accent : Ink.hairline, lineWidth: isSelected ? Metric.focusRing : Metric.hairline))
            .contentShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
        }
        .buttonStyle(.plain)
        .help("Show this Project's activity")
        .accessibilityLabel("\(project.name), \(Format.spokenTokens(project.totals.tokens)), \(Format.cost(project.totals.cost)), \(lastActive)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var lastActive: String {
        project.totals.last.map { "active " + $0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)) } ?? "–"
    }
}
