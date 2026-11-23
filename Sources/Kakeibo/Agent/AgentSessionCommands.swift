import AppKit
import Foundation
import KakeiboKit

/// M6 and M7 for agents: live sessions, today's timeline, and opening a
/// Project's folder. Listed in `AgentCommands.all`.
enum AgentSessionCommands {
    static let all: [AgentCommand] = [
        AgentCommand(name: "live", summary: "List Claude Code sessions that replied in the last 5 minutes, with their tokens.",
                     example: "kakeibo live --json", readOnly: true) { _, model in
            await model.usage.refresh()
            let live = model.usage.live
            return ["sessions": live.map {
                ["id": String($0.id.prefix(8)), "project": ($0.project as NSString).lastPathComponent, "path": $0.project,
                 "tokens": $0.tokens, "lastReply": JSON.date($0.last)] as JSONObject
            }, "total": live.count, "window": "5 minutes"]
        },
        AgentCommand(name: "timeline", summary: "Show today's sessions per Project: times, branch, first prompt, prompts and files changed.",
                     params: [.init(name: "project", help: "only this Project (folder name or path)"),
                              .init(name: "limit", kind: .integer, help: "at most this many Projects (default 10)")],
                     example: "kakeibo timeline --project Kakeibo --json", readOnly: true) { args, model in
            await model.usage.refresh()
            var entries = await model.usage.timeline()
            if let text = args.string("project") {
                let path = try AgentCommands.findProject(text, among: entries.map(\.project), scope: "active today")
                entries = entries.filter { $0.project == path }
            }
            let limit = try args.int("limit", default: 10)
            return ["date": JSON.date(Calendar.current.startOfDay(for: .now)),
                    "projects": entries.prefix(limit).map { entry in
                        ["name": (entry.project as NSString).lastPathComponent, "path": entry.project,
                         "sessions": entry.sessions.map(sessionJSON)] as JSONObject
                    },
                    "total": entries.count]
        },
        AgentCommand(name: "project open", summary: "Open a Project's folder in Finder, a terminal, or an editor on this Mac.",
                     params: [.init(name: "project", required: true, positional: true, help: "the Project's folder name or path"),
                              .init(name: "in", help: "finder (default), or an installed app: " + targetNames.joined(separator: ", "))],
                     example: "kakeibo project open Kakeibo --in ghostty") { args, model in
            let paths = await model.usage.yearProjects()
            let path = try AgentCommands.findProject(try args.required("project"), among: paths, scope: "active in the last year")
            guard ProjectOpener.canOpen(path) else { throw AgentError.notFound("the folder \(path) no longer exists") }
            let wanted = (args.string("in") ?? "finder").lowercased()
            let installed = ProjectOpener.targets
            let all = [installed.finder] + installed.terminals + installed.editors
            guard let target = all.first(where: { key($0) == wanted }) else {
                throw AgentError.usage("\"\(wanted)\" is not an installed app Kakeibo can open. Use one of: \(all.map(key).joined(separator: ", "))")
            }
            ProjectOpener.open(path, in: target)
            return ["opened": path, "in": target.name]
        },
    ]

    /// The `--in` value for an app: its name in lowercase, without spaces ("vscode").
    static func key(_ target: OpenTarget) -> String { target.name.lowercased().replacingOccurrences(of: " ", with: "") }

    /// Every app `--in` knows, installed or not, for help text.
    static var targetNames: [String] { (OpenTarget.terminals + OpenTarget.editors).map(key) }

    static func sessionJSON(_ session: TimelineSession) -> JSONObject {
        ["id": String(session.id.prefix(8)), "start": JSON.date(session.start), "end": JSON.date(session.end),
         "live": session.isLive(), "branch": session.branch ?? NSNull(), "firstPrompt": session.firstPrompt ?? NSNull(),
         "prompts": session.prompts, "files": session.files]
    }
}
