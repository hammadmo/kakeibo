import KakeiboKit
import SwiftData
import SwiftUI

/// Under a Project row: today's Summary, or Summarize, or the spinner and
/// Cancel while it runs, or why it failed (S-020 to S-022).
struct ProjectSummaryArea: View {
    @Environment(AppModel.self) private var model
    let project: String
    let activeToday: Bool
    @Query private var summaries: [Summary]

    init(project: String, activeToday: Bool) {
        self.project = project
        self.activeToday = activeToday
        let day = Calendar.current.startOfDay(for: .now)
        _summaries = Query(filter: #Predicate<Summary> { $0.project == project && $0.day == day })
    }

    var body: some View {
        let service = model.summaries
        let summary = summaries.first
        if service.isRunning(project) || summary != nil || service.errors[project] != nil {
            VStack(alignment: .leading, spacing: Space.sm) {
                if let summary, !service.isRunning(project) {
                    Text(summary.text)
                        .kitType(.body)
                        .foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let error = service.errors[project], !service.isRunning(project) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .kitType(.label)
                        .foregroundStyle(Ink.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Space.sm) {
                    if service.isRunning(project) {
                        ProgressView().controlSize(.small)
                        Text("Summarizing with Haiku…").kitType(.meta).foregroundStyle(Ink.textSoft)
                        Spacer()
                        Button("Cancel") { service.cancel(project) }
                            .buttonStyle(.kit(.ghost)).fixedSize()
                    } else {
                        if let summary {
                            Text("Summarized \(summary.createdAt.formatted(date: .omitted, time: .shortened)) · \(Format.tokens(summary.tokens)) tokens")
                                .kitType(.meta).foregroundStyle(Ink.textSoft)
                        }
                        Spacer()
                        Button(summary == nil ? "Try Again" : "Summarize Again") { service.summarize(project) }
                            .buttonStyle(.kit(.ghost))
                            .fixedSize()
                            .disabled(!activeToday)
                            .help(SummarizeButton.help(activeToday))
                    }
                }
            }
            .padding(.bottom, Space.sm)
        }
    }
}

/// The small inline Summarize beside a Project's name, before it has a
/// Summary (S-020). Hidden while running or once a Summary or error shows.
struct SummarizeButton: View {
    @Environment(AppModel.self) private var model
    let project: String
    let activeToday: Bool
    @Query private var summaries: [Summary]

    init(project: String, activeToday: Bool) {
        self.project = project
        self.activeToday = activeToday
        let day = Calendar.current.startOfDay(for: .now)
        _summaries = Query(filter: #Predicate<Summary> { $0.project == project && $0.day == day })
    }

    static func help(_ activeToday: Bool) -> String {
        activeToday
            ? "Ask Claude (Haiku) for two lines about today's work in this Project. Uses a few thousand tokens of your plan."
            : "No Claude Code activity in this Project today"
    }

    var body: some View {
        let service = model.summaries
        if activeToday, summaries.isEmpty, !service.isRunning(project), service.errors[project] == nil {
            Button("Summarize") { service.summarize(project) }
                .buttonStyle(.plain)
                .kitType(.labelStrong)
                .foregroundStyle(Ink.accentText)
                .help(Self.help(activeToday))
        }
    }
}
