import Foundation
import SwiftData
import KakeiboKit

/// Everything an agent can do in kakeibo. Add a command here and the CLI,
/// `help`, and the MCP tools all get it. Each `run` is on the main actor
/// with the app's model, and reads the same state the window shows.
enum AgentCommands {
    static let all: [AgentCommand] = core + AgentSessionCommands.all

    private static let core: [AgentCommand] = [
        AgentCommand(name: "status", summary: "Show whether Kakeibo runs, its login state, and when it last read limits and logs.",
                     example: "kakeibo status --json", readOnly: true) { _, model in
            ["running": true,
             "limits": statusName(model.limits.status),
             "limitsUpdatedAt": model.limits.updatedAt.map(JSON.date) ?? NSNull(),
             "logsRead": model.usage.hasRead,
             "todayTokens": model.usage.today.tokens]
        },
        AgentCommand(name: "limits", summary: "Show the Session, Weekly, and Fable limits: Used % and when each resets, plus the Weekly limit by surface.",
                     example: "kakeibo limits --json", readOnly: true) { _, model in
            guard let limits = model.limits.current else {
                throw AgentError.unavailable("no limits yet (\(statusName(model.limits.status))). Sign in with `claude` then /login, or run `kakeibo refresh`")
            }
            var result: JSONObject = ["status": statusName(model.limits.status),
                                      "updatedAt": model.limits.updatedAt.map(JSON.date) ?? NSNull()]
            for (key, window) in [("session", limits.session), ("weekly", limits.weekly), ("fable", limits.fable)] {
                if let window { result[key] = windowJSON(window) }
            }
            if let breakdown = limits.breakdown {
                result["weeklyBySurface"] = breakdown.rows.map {
                    ["surface": $0.name, "percentOfLimit": $0.shareOfLimit, "percentOfUse": $0.shareOfUse] as JSONObject
                }
            }
            return result
        },
        AgentCommand(name: "today", summary: "Show today's tokens and estimated cost (API prices), with the busiest Projects.",
                     params: [.init(name: "limit", kind: .integer, help: "at most this many Projects (default 5)")],
                     example: "kakeibo today --json", readOnly: true) { args, model in
            await model.usage.refresh()
            let limit = try args.int("limit", default: 5)
            let usage = model.usage
            return ["date": JSON.date(Calendar.current.startOfDay(for: .now)),
                    "tokens": usage.today.tokens, "costUSD": rounded(usage.today.cost), "replies": usage.today.replies,
                    "projects": usage.todayByProject.prefix(limit).map {
                        ["name": $0.name, "path": $0.id, "tokens": $0.totals.tokens, "costUSD": rounded($0.totals.cost)] as JSONObject
                    },
                    "projectCount": usage.todayByProject.count,
                    "note": "cost is an estimate at API prices, not a bill"]
        },
        AgentCommand(name: "week", summary: "Compare this week's tokens and cost with the same point last week.",
                     example: "kakeibo week --json", readOnly: true) { _, model in
            let data = await model.usage.dashboard(range: .week)
            return ["thisWeek": totalsJSON(data.thisWeek), "lastWeekSoFar": totalsJSON(data.lastWeekSoFar),
                    "changePercent": Weeks.change(this: Double(data.thisWeek.tokens), last: Double(data.lastWeekSoFar.tokens)).map { $0 as Any } ?? NSNull()]
        },
        AgentCommand(name: "days", summary: "List tokens and cost per day, split by model family.",
                     params: [.init(name: "days", kind: .integer, help: "7 or 30 (default 7)")],
                     example: "kakeibo days --days 30 --json", readOnly: true) { args, model in
            let range = try range(args)
            let data = await model.usage.dashboard(range: range)
            let byDay = Dictionary(grouping: data.byDay, by: \.day).sorted { $0.key < $1.key }
            return ["days": byDay.map { day, entries in
                ["date": JSON.date(day),
                 "tokens": entries.reduce(0) { $0 + $1.totals.tokens },
                 "costUSD": rounded(entries.reduce(0) { $0 + $1.totals.cost }),
                 "models": Dictionary(uniqueKeysWithValues: entries.map { ($0.family, $0.totals.tokens) })] as JSONObject
            }, "models": data.families.map {
                ["model": $0.family, "tokens": $0.totals.tokens, "costUSD": rounded($0.totals.cost)] as JSONObject
            }]
        },
        AgentCommand(name: "projects", summary: "List every Project's tokens, cost, and last activity in the last 7 or 30 days.",
                     params: [.init(name: "days", kind: .integer, help: "7 or 30 (default 7)"),
                              .init(name: "sort", help: "tokens (default), cost, name, or last"),
                              .init(name: "limit", kind: .integer, help: "at most this many (default 20)"),
                              .init(name: "offset", kind: .integer, help: "skip this many, for the next page")],
                     example: "kakeibo projects --days 30 --sort cost --json", readOnly: true) { args, model in
            let data = await model.usage.dashboard(range: try range(args))
            let sortName = args.string("sort") ?? "tokens"
            let sort: ProjectSort = switch sortName {
            case "tokens": .tokens
            case "cost": .cost
            case "name": .name
            case "last": .last
            default: throw AgentError.usage("--sort must be tokens, cost, name, or last")
            }
            let rows = sort.sorted(data.projects)
            let limit = try args.int("limit", default: 20)
            let offset = try args.int("offset", default: 0)
            let page = rows.dropFirst(offset).prefix(limit)
            var result: JSONObject = ["projects": page.map {
                ["name": $0.name, "path": $0.id, "tokens": $0.totals.tokens, "costUSD": rounded($0.totals.cost),
                 "lastActive": $0.totals.last.map(JSON.date) ?? NSNull()] as JSONObject
            }, "total": rows.count]
            if offset + page.count < rows.count { result["nextOffset"] = offset + page.count }
            return result
        },
        AgentCommand(name: "summary", summary: "Show today's Summary of a Project, if one was made.",
                     params: [.init(name: "project", required: true, positional: true, help: "the Project's folder name or path")],
                     example: "kakeibo summary Kakeibo --json", readOnly: true) { args, model in
            let project = try findProject(try args.required("project"), in: model)
            guard let summary = model.summaries.today(project) else {
                return ["project": project, "summary": NSNull(), "hint": "run `kakeibo summarize \((project as NSString).lastPathComponent) --yes` to make one"]
            }
            return ["project": project, "summary": summary.text, "tokens": summary.tokens, "createdAt": JSON.date(summary.createdAt)]
        },
        AgentCommand(name: "summarize", summary: "Ask Claude (Haiku) for two lines about today's work in a Project. Spends a few thousand tokens of your plan.",
                     params: [.init(name: "project", required: true, positional: true, help: "the Project's folder name or path")],
                     example: "kakeibo summarize Kakeibo --yes --json", destructive: true) { args, model in
            let project = try findProject(try args.required("project"), in: model)
            guard args.confirmed else {
                return ["summarized": false, "project": project,
                        "hint": "this spends a few thousand tokens of your Claude plan. Add --yes to run it"]
            }
            model.summaries.summarize(project)
            while model.summaries.isRunning(project) { try await Task.sleep(for: .milliseconds(200)) }
            if let error = model.summaries.errors[project] { throw AgentError.invalid(error) }
            guard let summary = model.summaries.today(project) else { throw AgentError.invalid("no Summary was made") }
            return ["summarized": true, "project": project, "summary": summary.text, "tokens": summary.tokens]
        },
        AgentCommand(name: "refresh", summary: "Fetch limits now (at most once a minute) and read new log lines.",
                     example: "kakeibo refresh --json") { _, model in
            await model.refreshNow()
            return ["limits": statusName(model.limits.status), "limitsUpdatedAt": model.limits.updatedAt.map(JSON.date) ?? NSNull(),
                    "todayTokens": model.usage.today.tokens]
        },
        AgentCommand(name: "open", summary: "Show a Dashboard page in its window.",
                     params: [.init(name: "page", required: true, positional: true,
                                    help: SidebarItem.allCases.map(\.rawValue).joined(separator: ", "))],
                     example: "kakeibo open projects") { args, model in
            let name = try args.required("page")
            guard let page = SidebarItem(rawValue: name) else {
                throw AgentError.usage("no page \"\(name)\". Pages: \(SidebarItem.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            model.sidebar = page
            Startup.openWindow?(id: Dashboard.windowID)
            return ["page": page.rawValue]
        },
    ]

    // MARK: Helpers

    static func statusName(_ status: LimitsService.Status) -> String {
        switch status {
        case .ok: "ok"
        case .loading: "loading"
        case .signedOut: "signed_out"
        case .expired: "expired"
        case .offline(let reason): "offline: \(reason)"
        }
    }

    static func windowJSON(_ window: LimitWindow) -> JSONObject {
        ["usedPercent": window.used,
         "resetsAt": window.resets.map(JSON.date) ?? NSNull(),
         "resets": ResetText.short(window.resets)]
    }

    static func totalsJSON(_ totals: UsageTotals) -> JSONObject {
        ["tokens": totals.tokens, "costUSD": rounded(totals.cost), "replies": totals.replies]
    }

    static func rounded(_ usd: Double) -> Double { (usd * 100).rounded() / 100 }

    static func range(_ args: Args) throws -> DashboardRange {
        let days = try args.int("days", default: 7)
        guard let range = DashboardRange(rawValue: days) else { throw AgentError.usage("--days must be 7 or 30") }
        return range
    }

    /// A Project path from its folder name, full path, or the start of either,
    /// among today's Projects (summary, summarize).
    static func findProject(_ text: String, in model: AppModel) throws -> String {
        try findProject(text, among: model.usage.todayByProject.map(\.id), scope: "active today")
    }

    static func findProject(_ text: String, among candidates: [String], scope: String) throws -> String {
        let paths = Set(candidates)
        let needle = text.lowercased()
        let exact = paths.filter { $0.lowercased() == needle || ($0 as NSString).lastPathComponent.lowercased() == needle }
        if exact.count == 1 { return exact.first! }
        let partial = paths.filter { ($0 as NSString).lastPathComponent.lowercased().hasPrefix(needle) }
        guard let first = partial.first else {
            throw AgentError.notFound("no Project \(scope) matches \"\(text)\". Run `kakeibo projects --days 30` for names")
        }
        guard partial.count == 1 else {
            throw AgentError.usage("\(partial.count) Projects start with \"\(text)\": \(partial.map { ($0 as NSString).lastPathComponent }.sorted().joined(separator: ", "))")
        }
        return first
    }
}
