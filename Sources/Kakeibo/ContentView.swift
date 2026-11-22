import SwiftData
import SwiftUI
import KakeiboKit

/// The Dashboard window. The menu bar item and popover come with S-004 and S-005.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch model.sidebar ?? .overview {
            case .overview: OverviewPage()
            case .projects: ProjectsPage()
            }
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarItem.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 212)
    }
}

/// Stored limit readings, newest first. Charts replace this list in M2.
struct OverviewPage: View {
    @Query(sort: \LimitSnapshot.takenAt, order: .reverse) private var snapshots: [LimitSnapshot]

    var body: some View {
        List(snapshots) { snapshot in
            HStack {
                Text(snapshot.takenAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary)
                Spacer()
                reading("Session", snapshot.sessionUsed)
                reading("Weekly", snapshot.weeklyUsed)
                if let fable = snapshot.fableUsed { reading("Fable", fable) } else { Color.clear.frame(width: 112) }
            }
            .monospacedDigit()
        }
        .overlay {
            if snapshots.isEmpty {
                ContentUnavailableView(
                    "No Limits Yet",
                    systemImage: SidebarItem.overview.symbol,
                    description: Text("Kakeibo shows your Session, Weekly, and Fable limits here.")
                )
            }
        }
        .navigationTitle(SidebarItem.overview.title)
    }

    private func reading(_ name: String, _ value: Double) -> some View {
        Text("\(name) \(Used(value).label)")
            .frame(width: 112, alignment: .trailing)
    }
}

struct ProjectsPage: View {
    var body: some View {
        ContentUnavailableView(
            "No Projects Yet",
            systemImage: SidebarItem.projects.symbol,
            description: Text("Kakeibo reads the logs in ~/.claude/projects.")
        )
        .navigationTitle(SidebarItem.projects.title)
    }
}
