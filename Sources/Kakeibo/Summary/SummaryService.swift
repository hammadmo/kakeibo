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

/// Running Claude Code's CLI. All of it is nonisolated and blocking; callers
/// run it off the main thread.
enum ClaudeCLI {
    /// APP_CLAUDE points tests at a fake CLI. Otherwise the usual install places,
    /// then the login shell's PATH.
    nonisolated static func find() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let path = env["APP_CLAUDE"] {
            return FileManager.default.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for path in ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let found = output(URL(fileURLWithPath: "/bin/zsh"), ["-lc", "command -v claude"], cwd: nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return found.flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
    }

    /// `claude auth status`: Claude Code reads its login and renews an expired
    /// access token. Spends no tokens. Gives up after 30 seconds.
    nonisolated static func renewLogin() {
        guard let claude = find() else { return }
        let process = Process()
        process.executableURL = claude
        process.arguments = ["auth", "status"]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        let deadline = Date.now.addingTimeInterval(30)
        while process.isRunning && Date.now < deadline { Thread.sleep(forTimeInterval: 0.2) }
        if process.isRunning { process.terminate() }
    }

    nonisolated static func lines(_ url: URL) -> [Data] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return data.split(separator: 0x0A).map { Data($0) }
    }

    /// Today's commit subjects, if the Project is a git repository.
    nonisolated static func commits(in project: String, since start: Date) -> [String] {
        guard FileManager.default.fileExists(atPath: project + "/.git") else { return [] }
        let since = ISO8601DateFormatter().string(from: start)
        let text = output(URL(fileURLWithPath: "/usr/bin/git"), ["log", "--since=\(since)", "--pretty=%s", "-n", "50"],
                          cwd: URL(fileURLWithPath: project))
        return text?.split(whereSeparator: \.isNewline).map(String.init) ?? []
    }

    /// `claude -p` with Haiku, no tools, no MCP servers, and no session file
    /// (so a Summary never shows up as a Project). Cancelling the task stops it.
    nonisolated static func summarize(_ claude: URL, message: String) async -> Result<SummaryReply, SummaryService.Message> {
        let process = Process()
        process.executableURL = claude
        process.arguments = ["-p", "--model", "haiku", "--output-format", "json", "--no-session-persistence",
                             "--tools", "", "--strict-mcp-config", "--system-prompt", Digest.systemPrompt]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { finished in
                    let out = output.fileHandleForReading.readDataToEndOfFile()
                    let err = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    let parsed = SummaryReply.parse(out)
                    if finished.terminationStatus == 0, let reply = parsed.reply {
                        continuation.resume(returning: .success(reply))
                    } else {
                        let text = parsed.error ?? SummaryReply.firstLine(err) ?? "Claude Code stopped (exit \(finished.terminationStatus))."
                        continuation.resume(returning: .failure(.init(text: text)))
                    }
                }
                do {
                    try process.run()
                    input.fileHandleForWriting.write(Data(message.utf8))
                    try? input.fileHandleForWriting.close()
                } catch {
                    continuation.resume(returning: .failure(.init(text: "Unable to start Claude Code: \(error.localizedDescription)")))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    nonisolated private static func output(_ tool: URL, _ arguments: [String], cwd: URL?) -> String? {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
