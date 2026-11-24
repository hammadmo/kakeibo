import Foundation
import KakeiboKit

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

    /// Renews Claude Code's expired access token. `claude auth status` only
    /// reads the login, so this makes one tiny real call instead: Claude Code
    /// renews the token with its refresh token before any request. Haiku, no
    /// tools, no MCP servers, no session file; about 1,000 tokens. Gives up
    /// after 60 seconds.
    nonisolated static func renewLogin() {
        guard let claude = find() else { return }
        let process = Process()
        process.executableURL = claude
        process.arguments = ["-p", "--model", "haiku", "--output-format", "json", "--no-session-persistence",
                             "--tools", "", "--strict-mcp-config", "--system-prompt", "Reply with one word."]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe()
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        input.fileHandleForWriting.write(Data("ok".utf8))
        try? input.fileHandleForWriting.close()
        let deadline = Date.now.addingTimeInterval(60)
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
