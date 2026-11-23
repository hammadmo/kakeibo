import KakeiboKit
import SwiftUI

/// The Dashboard's Projects page: a year of activity (S-016) and every
/// Project's totals in the range (S-014).
struct ProjectsPage: View {
    @Environment(AppModel.self) private var model
    @State private var data = DashboardData()
    /// The Project the heatmap shows; a card or the menu picks it (S-050).
    @State private var heatProject: String?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Space.xl) {
            ProjectCards(projects: data.projects, selected: $heatProject)
            ActivityHeatmapCard(project: $heatProject)
            ProjectTable(projects: data.projects, range: $model.dashboardRange)
        }
        .task(id: "\(model.dashboardRange.rawValue)-\(model.usage.version)") {
            data = await model.usage.dashboard(range: model.dashboardRange)
        }
    }
}

/// How the Project list is sorted. The header buttons pick one.
enum ProjectSort: String, CaseIterable {
    case name = "Project", tokens = "Tokens", cost = "Cost", last = "Last active"

    func sorted(_ rows: [DashboardData.Project]) -> [DashboardData.Project] {
        switch self {
        case .name: rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .tokens: rows.sorted { $0.totals.tokens > $1.totals.tokens }
        case .cost: rows.sorted { $0.totals.cost > $1.totals.cost }
        case .last: rows.sorted { ($0.totals.last ?? .distantPast) > ($1.totals.last ?? .distantPast) }
        }
    }
}

/// S-014: name, Tokens, Cost, last activity. Most Tokens first.
private struct ProjectTable: View {
    @Environment(AppModel.self) private var model
    let projects: [DashboardData.Project]
    @Binding var range: DashboardRange
    @State private var sort = ProjectSort.tokens

    private var activeToday: Set<String> { Set(model.usage.todayByProject.map(\.id)) }

    private static let numberWidth: CGFloat = 96
    private static let lastWidth: CGFloat = 112

    var body: some View {
        DashboardCard(title: "Projects") {
            RangePicker(range: $range)
        } content: {
            if projects.isEmpty {
                Text("No Projects in this range. They show here once Claude Code works in them.")
                    .kitType(.label).foregroundStyle(Ink.textSoft)
            } else {
                table
            }
        }
    }

    private var table: some View {
            VStack(spacing: 0) {
                HStack(spacing: Space.sm) {
                    header(.name).frame(maxWidth: .infinity, alignment: .leading)
                    header(.tokens).frame(width: Self.numberWidth, alignment: .trailing)
                    header(.cost).frame(width: Self.numberWidth, alignment: .trailing)
                    header(.last).frame(width: Self.lastWidth, alignment: .trailing)
                }
                .padding(.bottom, Space.sm)
                KitDivider()
                ForEach(Array(sort.sorted(projects).enumerated()), id: \.element.id) { index, project in
                    if index > 0 { KitDivider() }
                    row(project)
                    ProjectSummaryArea(project: project.id, activeToday: activeToday.contains(project.id))
                }
            }
    }

    private func header(_ column: ProjectSort) -> some View {
        Button {
            sort = column
        } label: {
            HStack(spacing: 2) {
                Text(column.rawValue)
                if sort == column { Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)) }
            }
            .kitType(.labelStrong)
            .foregroundStyle(sort == column ? Ink.accentText : Ink.textSoft)
        }
        .buttonStyle(.plain)
        .help("Sort by \(column.rawValue.lowercased())")
        .accessibilityAddTraits(sort == column ? .isSelected : [])
    }

    private func row(_ project: DashboardData.Project) -> some View {
        HStack(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                Text(project.name).kitType(.body).foregroundStyle(Ink.text)
                    .lineLimit(1).truncationMode(.middle).help(project.id)
                SummarizeButton(project: project.id, activeToday: activeToday.contains(project.id))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.tokens(project.totals.tokens)).kitType(.label).foregroundStyle(Ink.text)
                .monospacedDigit()
                .frame(width: Self.numberWidth, alignment: .trailing)
            Text(Format.cost(project.totals.cost)).kitType(.label).foregroundStyle(Ink.textSoft)
                .monospacedDigit()
                .frame(width: Self.numberWidth, alignment: .trailing)
            Text(project.totals.last.map { $0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)) } ?? "–")
                .kitType(.meta).foregroundStyle(Ink.textSoft)
                .frame(width: Self.lastWidth, alignment: .trailing)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }
}

/// S-016: 53 weeks × 7 days of Tokens in five gold steps, for every
/// Project or the one picked above it. Hover shows the day and its Tokens.
private struct ActivityHeatmapCard: View {
    @Environment(AppModel.self) private var model
    @Binding var project: String?
    @State private var projects: [String] = []
    @State private var days: [Date: Int] = [:]

    var body: some View {
        DashboardCard(title: "Activity") {
            Menu {
                Button("All Projects") { project = nil }
                Divider()
                ForEach(projects, id: \.self) { path in
                    Button((path as NSString).lastPathComponent) { project = path }
                }
            } label: {
                HStack(spacing: Space.xs) {
                    Text(project.map { ($0 as NSString).lastPathComponent } ?? "All Projects")
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
                .kitType(.labelStrong)
                .foregroundStyle(Ink.accentText)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Show one Project's activity")
            .accessibilityLabel("Project")
        } content: {
            HeatGrid(days: days)
            HStack(spacing: Space.xs) {
                Text("Less").kitType(.meta).foregroundStyle(Ink.textSoft)
                ForEach(0..<5) { step in
                    RoundedRectangle(cornerRadius: 2).fill(Ink.heat(step))
                        .frame(width: Metric.heatCell, height: Metric.heatCell)
                }
                Text("More").kitType(.meta).foregroundStyle(Ink.textSoft)
            }
            .accessibilityHidden(true)
        }
        .task(id: "\(project ?? "all")-\(model.usage.version)") {
            days = await model.usage.heatmap(project: project)
            projects = await model.usage.yearProjects()
        }
    }
}

private struct HeatGrid: View {
    let days: [Date: Int]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let first = calendar.date(byAdding: .weekOfYear, value: -52, to: thisWeek) ?? thisWeek
        let thresholds = HeatSteps.thresholds(Array(days.values))
        HStack(alignment: .top, spacing: Metric.heatGap) {
            ForEach(0..<53, id: \.self) { week in
                VStack(spacing: Metric.heatGap) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: first) ?? first
                        let tokens = days[day] ?? 0
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(day > today ? Color.clear : Ink.heat(HeatSteps.step(tokens, thresholds: thresholds)))
                            .frame(width: Metric.heatCell, height: Metric.heatCell)
                            .help(day > today ? "" : "\(day.formatted(.dateTime.weekday(.abbreviated).day().month().year())): \(Format.tokens(tokens)) tokens")
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity over the last year")
        .accessibilityValue("\(days.values.filter { $0 > 0 }.count) active days")
    }
}
