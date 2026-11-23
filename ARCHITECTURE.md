# Kakeibo architecture

## Targets
- `KakeiboKit` (no UI): `UsageLog` byte-scanning parser, `UsageStore` actor (incremental, parallel
  reads of `~/.claude/projects/**/*.jsonl`), `Pricing`, `Limits` decoding, `ResetText`, `Format`, `Used`.
- `Kakeibo` (app) depends on KakeiboKit.

## App
- `App.swift`: `MenuBarExtra` (popover), the Dashboard `Window`, a snapshot-only popover window,
  `Settings`. Activation is `.accessory` until a titled window opens.
- `AppModel`: shared state; owns `LimitsService` (Keychain login → OAuth usage endpoint every 5 min,
  stores `LimitSnapshot` in SwiftData) and `UsageService` (re-reads logs every minute).
- `Startup.run` starts timers and test modes, called from the menu bar label and the Dashboard
  (test runs open the Dashboard, so they never depend on the menu bar having room).
- `DesignKit/`: Hachibu's kit (`Ink`, `KitType`, `Metric`, `EnsoGauge`, buttons) + `kitCard()`. See design/KIT.md.

## Summary (M3)
`SummaryService` builds a `Digest` (KakeiboKit) from the Project's own log files (`UsageStore.files(of:)`) and
`git log`, then runs `claude -p --model haiku --output-format json --no-session-persistence --tools ""` off the main
thread. One `Summary` (SwiftData) per Project and day. Tests point `APP_CLAUDE` at a fake CLI.

## Threading
Log parsing runs in the `UsageStore` actor, files in a task group. Network uses URLSession async.
Everything else is main actor.

## Test seams
`APP_STORE` in /tmp switches to fixture limits (`APP_LIMITS`) and fixture logs (`/tmp/Kakeibo-logs`,
written by `SeedData.writeLogs`). Self-test: `tools/selftest.sh`. Snapshots: `tools/snap.sh`.

## Agent CLI and MCP
`Main.swift` starts the CLI when there are arguments, else the app. `kakeibo <command>` sends one JSON line over
a private Unix socket (`~/Library/Application Support/Kakeibo/agent.sock`) to the running app, which runs it on the
main actor (`AgentRouter`, async: commands may await the usage actor or a Summarize run). `kakeibo mcp` serves
the same commands as MCP tools. Commands: `Agent/AgentCommands.swift`. All read-only except `refresh`, `open`,
and `summarize` (spends plan tokens, needs `--yes`). `build.sh` links `~/.local/bin/kakeibo`.

## Updates
Sparkle 2 (`Updates.swift`, like Hachibu): feed `appcast.xml` on `github.com/hammadmo/kakeibo`, downloads from its
releases, each checked against `SUPublicEDKey`. `build.sh` embeds Sparkle in `Contents/Frameworks` and signs its
helpers inside out. Never runs in test, CLI, or one-shot runs. Releases: `tools/release.sh`, `docs/RELEASING.md`.

## Claude Code's CLI
`ClaudeCode/ClaudeCLI.swift`: everything that runs or reads Claude Code from the outside, nonisolated and blocking
(callers run it detached): `find()` (APP_CLAUDE for tests, the usual install places, then the login shell's PATH),
`summarize` (Summaries), `renewLogin` (`claude auth status`, when the Keychain token has expired), `lines` (log files),
and `commits` (git). Used by Summary, Limits, and the Today timeline.

## Today, live sessions, and opening Projects (M6, M7)
`Timeline` and `UsageStore.liveSessions` in KakeiboKit; `UsageService.timeline()` reads a Project's own log files
detached. `ProjectOpener` opens folders over `NSWorkspace`; which apps are offered is `OpenTarget` in KakeiboKit.
The daily Alert can call `SummaryService.summarizeAndWait` for the three busiest Projects (Settings > Alerts).
