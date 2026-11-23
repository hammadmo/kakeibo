import Foundation
import Observation
import SwiftData
import KakeiboKit

/// Summarize (S-020 to S-022): builds a Project's digest for today, asks
/// Claude Code's Haiku for two sentences, and keeps one Summary per day.
@MainActor
@Observable
final class SummaryService {
    /// Projects being summarized now, with their running task.
    private(set) var running: [String: Task<Void, Never>] = [:]
    /// The last error per Project, shown under its row until the next try.
    private(set) var errors: [String: String] = [:]

    private let container: ModelContainer
    private let usage: UsageService

    init(container: ModelContainer, usage: UsageService) {
        self.container = container
        self.usage = usage
    }

    func isRunning(_ project: String) -> Bool { running[project] != nil }

    /// Today's Summary for a Project, if there is one.
    func today(_ project: String) -> Summary? {
        let day = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Summary>(predicate: #Predicate { $0.project == project && $0.day == day })
        return try? container.mainContext.fetch(descriptor).first
    }

    func summarize(_ project: String) {
        guard running[project] == nil else { return }
        errors[project] = nil
        running[project] = Task {
            defer { running[project] = nil }
            let result = await run(project)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let reply): save(project: project, reply: reply)
            case .failure(let message): errors[project] = message.text
            }
        }
    }

    /// Summarize and wait for it (S-060). True when today's Summary was made.
    func summarizeAndWait(_ project: String) async -> Bool {
        summarize(project)
        await running[project]?.value
        return errors[project] == nil && today(project) != nil
    }

    func cancel(_ project: String) {
        running[project]?.cancel()
        running[project] = nil
    }

    // MARK: Work off the main thread

    struct Message: Error { let text: String }

    private func run(_ project: String) async -> Result<SummaryReply, Message> {
        guard let claude = ClaudeCLI.find() else {
            return .failure(Message(text: "Unable to find Claude Code. Install it, then try again."))
        }
        let files = await usage.store.files(of: project)
        let start = Calendar.current.startOfDay(for: .now)
        let digest = await Task.detached(priority: .userInitiated) {
            var digest = Digest.build(lines: files.flatMap(ClaudeCLI.lines), project: project, from: start)
            digest.commits = ClaudeCLI.commits(in: project, since: start)
            return digest
        }.value
        guard !digest.isEmpty else {
            return .failure(Message(text: "Nothing to summarize: no prompts, edits, or commits today."))
        }
        let name = (project as NSString).lastPathComponent
        return await ClaudeCLI.summarize(claude, message: digest.message(projectName: name))
    }

    private func save(project: String, reply: SummaryReply) {
        let context = container.mainContext
        let day = Calendar.current.startOfDay(for: .now)
        if let old = today(project) { context.delete(old) }
        context.insert(Summary(project: project, day: day, text: reply.text, tokens: reply.tokens))
        try? context.save()
    }
}
