import KakeiboKit
import SwiftUI

/// S-051: what happened today in each Project, one row per session.
struct TodayPage: View {
    @Environment(AppModel.self) private var model
    @State private var projects: [(project: String, sessions: [TimelineSession])] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            if loaded && projects.isEmpty {
                KitEmptyState(title: "Nothing Yet Today", message: "Sessions show here as Claude Code works.")
            }
            ForEach(projects, id: \.project) { entry in
                DashboardCard(title: (entry.project as NSString).lastPathComponent) {
                    HStack(spacing: Space.md) {
                        Text("\(entry.sessions.count) \(entry.sessions.count == 1 ? "session" : "sessions")")
                            .kitType(.meta).foregroundStyle(Ink.textSoft)
                        OpenProjectMenu(path: entry.project)
                    }
                } content: {
                    VStack(spacing: 0) {
                        ForEach(Array(entry.sessions.reversed().enumerated()), id: \.element.id) { index, session in
                            if index > 0 { KitDivider() }
                            SessionRow(session: session)
                        }
                    }
                }
                .help(entry.project)
            }
        }
        .task(id: model.usage.version) {
            projects = await model.usage.timeline()
            loaded = true
        }
    }
}

private struct SessionRow: View {
    let session: TimelineSession

    var body: some View {
        let live = session.isLive()
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                if live { LiveDot() }
                Text(times(live: live)).kitType(.labelStrong).foregroundStyle(Ink.text).monospacedDigit()
            }
            .frame(width: 128, alignment: .leading)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(session.firstPrompt ?? "No prompts typed in this session")
                    .kitType(.body)
                    .foregroundStyle(session.firstPrompt == nil ? Ink.textSoft : Ink.text)
                    .lineLimit(2)
                Text(meta).kitType(.meta).foregroundStyle(Ink.textSoft)
                    .help(session.files.isEmpty ? "" : session.files.joined(separator: "\n"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(live ? "Live, " : "")\(times(live: live)), \(session.firstPrompt ?? "no prompts"), \(meta)")
    }

    private func times(live: Bool) -> String {
        let start = session.start.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(live ? "now" : session.end.formatted(date: .omitted, time: .shortened))"
    }

    private var meta: String {
        var parts: [String] = []
        if let branch = session.branch { parts.append(branch) }
        parts.append("\(session.prompts) \(session.prompts == 1 ? "prompt" : "prompts")")
        parts.append("\(session.files.count) \(session.files.count == 1 ? "file" : "files")")
        return parts.joined(separator: " · ")
    }
}

/// A gold dot that pulses while a session is live (a still dot with Reduce Motion).
struct LiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Circle().fill(Ink.accent)
            .frame(width: Metric.statusDot, height: Metric.statusDot)
            .opacity(dim ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion, !Snapshot.isRunning else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .help("Claude Code replied in this session in the last 5 minutes")
            .accessibilityHidden(true)
    }
}
