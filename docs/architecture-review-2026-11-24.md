# Architecture review, 2026-11-24 (after M6, M7, and the agent commands)

Survey: 6,760 lines of Swift. Largest files: `DesignKit/EnsoGauge.swift` (301), `Dashboard/OverviewPage.swift` (286),
`SelfTest.swift` (242), `SettingsView.swift` (235). No file near 600, no copied `private struct`s. Most changed in 30 days:
`SelfTest.swift` (14 commits), `App.swift` (11), `Models.swift` (10). Fix log: 8 entries; snapshots appear twice, every
other area once, so no repeated area. Pure logic stays in KakeiboKit (39 tests); app services are `@MainActor` and do their
slow work in the `UsageStore` actor or detached tasks.

## Claude Code's CLI in its own file  [Strong, done 2026-11-24]

Files: Sources/Kakeibo/Summary/SummaryService.swift (192 lines, of which `ClaudeCLI` is about 100)
Signal: a module lives far from its users (it is part of three features).
Problem: `ClaudeCLI` finds the `claude` binary, runs Summaries, renews the login, reads log files, and reads git commits.
Limits (`renewLogin`) and the Today timeline (`lines`) now call it, but it sits inside the Summary feature's file, so a
change to login renewal means editing `SummaryService.swift`.
Proposal: move `enum ClaudeCLI` unchanged to `Sources/Kakeibo/ClaudeCode/ClaudeCLI.swift`. Its interface stays the same:
`find()`, `summarize(_:message:)`, `renewLogin()`, `lines(_:)`, `commits(in:since:)`.
Benefits: locality: each Claude Code integration has one home; `SummaryService.swift` shrinks to the Summary feature.
Proof of same behavior: a pure move. Build, 39 unit tests, 35 self-test checks (Summarize, daily Summaries, renewal
through the fake CLI), and `check-agent-cli.sh` give the same results before and after.
Plan: one commit (move the code, no edits).

## One reader for Claude Code log lines  [Worth exploring]

Files: Sources/KakeiboKit/Digest.swift, Sources/KakeiboKit/Timeline.swift
Signal: drifted copies. Both decode the same JSON lines and repeat the changed-file loop (Edit, Write, MultiEdit,
NotebookEdit; the path relative to the Project).
Problem: a new tool name (or a renamed field) has to be fixed in two places, and the Today page and a Summary read the
same files twice.
Proposal:
```swift
public enum LogEvent { case prompt(String), edit(file: String) }
public struct LogLine { let session: String; let time: Date; let branch: String?; let event: LogEvent? }
public enum LogReader { static func lines(_ data: [Data], project: String, from: Date) -> [LogLine] }
// Digest.build and Timeline.build become folds over [LogLine].
```
Benefits: one place for the log format; Digest and Timeline tests keep their expectations.
Proof: DigestTests and TimelineTests unchanged and passing; the Today snapshot and a Summary through the fake CLI unchanged.
Plan: 1) add LogReader with tests, 2) move Digest over, 3) move Timeline over, 4) delete the duplicated loops.
Do it when a third reader appears or the log format changes.

## Self-test split by feature  [Speculative]

Files: Sources/Kakeibo/SelfTest.swift (242 lines, the most changed file)
Every story adds checks at the end of one `Task`. At about 400 lines, split it into one function per feature
(limits, usage, summaries, alerts, settings) called in order. Not yet: it reads top to bottom and is still short.

## Top recommendation

Move `ClaudeCLI` into its own file. It's Strong, a pure move, and done in this check-in.

## Considered, not recommended
- `AppModel` as a god model: it only owns the services and two bits of page state; the services hold the logic.
- Fixtures in `LimitsService.applyFixture` (now six states): still one small switch, used only in test runs.
- `timeline()` living in `DashboardData.swift`: it's a `UsageService` query like the others there; fine.
