import Foundation

/// One Claude Code session today in a Project (S-051, S-052).
public struct TimelineSession: Equatable, Sendable, Identifiable {
    public var id: String
    public var start: Date
    public var end: Date
    public var branch: String?
    /// The first prompt, cut to 120 characters.
    public var firstPrompt: String?
    public var prompts: Int
    public var files: [String]

    /// Live: the newest line is under 5 minutes old.
    public static let liveWindow: TimeInterval = 300
    public func isLive(now: Date = .now) -> Bool { now.timeIntervalSince(end) < Self.liveWindow }
}

public enum Timeline {
    public static let promptLength = 120

    /// Today's sessions in one Project, oldest first, from its log lines.
    public static func build(lines: [Data], project: String, from start: Date) -> [TimelineSession] {
        var sessions: [String: TimelineSession] = [:]
        var seenFiles: [String: Set<String>] = [:]
        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = object["type"] as? String, type == "user" || type == "assistant",
                  (object["cwd"] as? String) == project,
                  let id = object["sessionId"] as? String,
                  let stamp = object["timestamp"] as? String, let time = Timestamp.parse(stamp), time >= start
            else { continue }
            var session = sessions[id] ?? TimelineSession(id: id, start: time, end: time, branch: nil,
                                                          firstPrompt: nil, prompts: 0, files: [])
            session.start = min(session.start, time)
            session.end = max(session.end, time)
            if let branch = object["gitBranch"] as? String, !branch.isEmpty, branch != "HEAD" { session.branch = branch }
            let message = object["message"] as? [String: Any]
            if type == "user", object["isMeta"] as? Bool != true, let text = Digest.promptText(message?["content"]) {
                session.prompts += 1
                if session.firstPrompt == nil { session.firstPrompt = String(text.prefix(promptLength)) }
            } else if type == "assistant", let blocks = message?["content"] as? [[String: Any]] {
                for block in blocks where block["type"] as? String == "tool_use" {
                    guard let name = block["name"] as? String, ["Edit", "Write", "MultiEdit", "NotebookEdit"].contains(name),
                          let input = block["input"] as? [String: Any],
                          let path = (input["file_path"] ?? input["notebook_path"]) as? String else { continue }
                    let shown = path.hasPrefix(project + "/") ? String(path.dropFirst(project.count + 1)) : (path as NSString).lastPathComponent
                    if seenFiles[id, default: []].insert(shown).inserted { session.files.append(shown) }
                }
            }
            sessions[id] = session
        }
        return sessions.values.sorted { $0.start < $1.start }
    }
}
