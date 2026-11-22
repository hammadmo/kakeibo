import SwiftData
import SwiftUI
import KakeiboKit

/// The Dashboard window, drawn with the design kit like Hachibu's History:
/// a hidden title bar, text tabs for the pages, and cards. M2 adds the charts.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            KitTabBar(tabs: SidebarItem.allCases.map { (id: $0, title: $0.title) },
                      selection: Binding(get: { model.sidebar ?? .overview }, set: { model.sidebar = $0 }),
                      label: "Dashboard pages")
                .padding(.top, Metric.titleBarInset)
                .padding(.bottom, Space.sm)
            KitDivider()
            ScrollView {
                Group {
                    switch model.sidebar ?? .overview {
                    case .overview: OverviewPage()
                    case .projects: ProjectsPage()
                    }
                }
                .padding(Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(minHeight: 360, idealHeight: 520)
        }
        .kitWindow(width: Metric.dashboardWidth)
        .task { Startup.run(model: model, openWindow: openWindow) }
    }
}

/// Stored limit readings, newest first. Charts replace this list in M2.
struct OverviewPage: View {
    @Query(sort: \LimitSnapshot.takenAt, order: .reverse) private var snapshots: [LimitSnapshot]

    var body: some View {
        if snapshots.isEmpty {
            KitEmptyState(title: "No Limits Yet",
                          message: "Kakeibo shows your Session, Weekly, and Fable limits here.")
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Limit readings").kitType(.section).foregroundStyle(Ink.accentText)
                VStack(spacing: 0) {
                    ForEach(Array(snapshots.prefix(24).enumerated()), id: \.element.id) { index, snapshot in
                        if index > 0 { KitDivider() }
                        row(snapshot)
                    }
                }
                .kitCard()
            }
        }
    }

    private func row(_ snapshot: LimitSnapshot) -> some View {
        HStack {
            Text(snapshot.takenAt, format: .dateTime.day().month().hour().minute())
                .kitType(.meta)
                .foregroundStyle(Ink.textSoft)
            Spacer()
            reading("Session", snapshot.sessionUsed)
            reading("Weekly", snapshot.weeklyUsed)
            if let fable = snapshot.fableUsed { reading("Fable", fable) } else { Color.clear.frame(width: 112) }
        }
        .padding(.vertical, Space.sm)
    }

    private func reading(_ name: String, _ value: Double) -> some View {
        let used = Used(value)
        return Text("\(name) \(used.label)")
            .kitType(.label)
            .foregroundStyle(used.isAlmostReached ? Ink.warning : Ink.text)
            .frame(width: 112, alignment: .trailing)
    }
}

struct ProjectsPage: View {
    var body: some View {
        KitEmptyState(title: "No Projects Yet", message: "Kakeibo reads the logs in ~/.claude/projects.")
    }
}

/// An empty page: what it is for, centered, in the kit's type.
struct KitEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.sm) {
            SealMark()
            Text(title).kitType(.status).foregroundStyle(Ink.text)
            Text(message).kitType(.label).foregroundStyle(Ink.textSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}
