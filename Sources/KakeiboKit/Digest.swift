import Foundation

/// What Haiku reads to summarize a Project's day (S-020): only the user's own
/// prompts (first 200 characters each), the names of files Claude changed,
/// and the day's git commits. Never tool output or Claude's replies.
public struct Digest: Equatable, Sendable {
    public var prompts: [String] = []
    public var files: [String] = []
    public var commits: [String] = []

    public init(prompts: [String] = [], files: [String] = [], commits: [String] = []) {
        self.prompts = prompts
        self.files = files
        self.commits = commits
    }

    public var isEmpty: Bool { prompts.isEmpty && files.isEmpty && commits.isEmpty }

    public static let promptLength = 200
    /// About 6,000 tokens at ~4 characters a token.
    public static let characterBudget = 24_000

    /// Reads the Project's log lines from `start` on. Lines from other
    /// Projects (a log can hold a moved session) are skipped.
    public static func build(lines: [Data], project: String, from start: Date) -> Digest {
        var digest = Digest()
        var seenFiles = Set<String>()
        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = object["type"] as? String, type == "user" || type == "assistant",
                  (object["cwd"] as? String) == project,
                  let stamp = object["timestamp"] as? String, let time = Timestamp.parse(stamp), time >= start,
                  let message = object["message"] as? [String: Any]
            else { continue }
            if type == "user", object["isMeta"] as? Bool != true, let text = promptText(message["content"]) {
                digest.prompts.append(String(text.prefix(promptLength)))
            } else if type == "assistant", let blocks = message["content"] as? [[String: Any]] {
                for block in blocks where block["type"] as? String == "tool_use" {
                    guard let name = block["name"] as? String, ["Edit", "Write", "MultiEdit", "NotebookEdit"].contains(name),
                          let input = block["input"] as? [String: Any],
                          let path = (input["file_path"] ?? input["notebook_path"]) as? String else { continue }
                    let shown = path.hasPrefix(project + "/") ? String(path.dropFirst(project.count + 1)) : (path as NSString).lastPathComponent
                    if seenFiles.insert(shown).inserted { digest.files.append(shown) }
                }
            }
        }
        return digest
    }

    /// A typed prompt: plain text, not a tool result, a slash command's
    /// wrapper, or a system note (those start with "<").
    static func promptText(_ content: Any?) -> String? {
        var text: String?
        if let string = content as? String {
            text = string
        } else if let blocks = content as? [[String: Any]] {
            text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.first
        }
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              !trimmed.hasPrefix("<") else { return nil }
        return trimmed.replacingOccurrences(of: "\n", with: " ")
    }

    /// The message Haiku gets, within the budget: commits and files first
    /// (small and telling), then prompts newest first until the budget is spent.
    public func message(projectName: String) -> String {
        var out = "Project: \(projectName)\n"
        func add(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            out += "\n\(title):\n"
            for item in items {
                let line = "- \(item)\n"
                guard out.count + line.count <= Self.characterBudget else { return }
                out += line
            }
        }
        add("Git commits today", commits)
        add("Files changed today", files)
        add("What I asked Claude today (newest first)", prompts.reversed())
        return out
    }

    public static let systemPrompt = """
        You summarize a developer's day in one project from their own notes. \
        Write exactly two short sentences in plain English: what was worked on and what changed. \
        No preamble, no lists, no markdown.
        """
}

/// The reply of `claude -p --output-format json`.
public struct SummaryReply: Equatable, Sendable {
    public var text: String
    public var tokens: Int

    /// nil reply means Claude Code failed; `error` holds its message, or is nil
    /// when stdout was empty (then stderr says why).
    public static func parse(_ data: Data) -> (reply: SummaryReply?, error: String?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not JSON: its first line, or nil for nothing, so the caller can use stderr.
            return (nil, firstLine(String(decoding: data, as: UTF8.self)))
        }
        let result = (object["result"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if object["is_error"] as? Bool == true || result.isEmpty {
            return (nil, firstLine(result) ?? "Claude Code gave no answer.")
        }
        let usage = object["usage"] as? [String: Any] ?? [:]
        let tokens = ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
            .reduce(0) { $0 + ((usage[$1] as? NSNumber)?.intValue ?? 0) }
        return (SummaryReply(text: result, tokens: tokens), nil)
    }

    /// The first non-empty line, for error messages.
    public static func firstLine(_ text: String) -> String? {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }
}
