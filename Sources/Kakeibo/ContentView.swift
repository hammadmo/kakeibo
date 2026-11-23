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
