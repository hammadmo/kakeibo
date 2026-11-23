# Kakeibo stories

Source: `docs/BRIEF.md`. No reference screenshots exist, so `Screens:` names the snapshot pages that will show each story. Terms follow `docs/GLOSSARY.md`.

Snapshot pages: `menubar-{light,dark}`, `popover-{light,dark}`, `popover-warning-dark`, `popover-signedout-dark`, `popover-offline-dark`, `dashboard-{light,dark}`, `dashboard-empty-dark`, `summary-dark`, `settings-{light,dark}`, `kit-gallery-{light,dark}`.

Seed data (snapshot mode): fixture JSONL logs for 4 projects × 30 days, 3 models (Opus, Sonnet, Fable). A fixture limits response with Session 42%, Weekly 18%, Fable 63%, and a warning variant with Session 92%. Everything the seed sets comes from logs or limits the app reads, so the user creates none of it.

---

## M1 Glance: see my limits from the menu bar

### S-001 Draw the app in the Hachibu and Jubako kit
As the user, I see Kakeibo in the same lacquered look as Hachibu and Jubako.
Screens: kit-gallery-light.png, kit-gallery-dark.png
Acceptance:
- [unit] `Ink` tokens match Hachibu's `design/KIT.md` hex values in light and dark. (Tokens.swift is copied verbatim from Hachibu.)
- [snap] The gallery shows the Gauge at 0, 42, 63, 92, and 100%, the 家 Seal, the raised card, and the primary and secondary buttons, in light and dark.
- [snap] At 92% the Gauge ring uses `warning` and the Seal shows.
Status: done
UX:
- Surface: none; parts only.
- Access: the Gauge's accessibility value reads "Session limit, 42% used, resets in 2 hours 14 minutes"; the warning adds the word "Almost reached", not only a color.

### S-002 Read token usage from Claude Code logs
As the user, Kakeibo knows how many tokens each project and model used, without my setting anything up.
Screens: popover-dark.png
Acceptance:
- [unit] The parser reads `~/.claude/projects/**/*.jsonl` and sums input, output, cache-write, and cache-read tokens by day, model, and project.
- [unit] A message logged twice (same message id and request id) counts once.
- [unit] Cost = tokens × a price table per model; an unknown model counts tokens and adds $0 cost, flagged `unknownModel`.
- [unit] Re-reading after new lines only parses the new bytes (offset per file).
- [unit] Every real log (2.5 GB, 50k replies on this Mac) parses in under 2 s off the main thread, files in parallel; a refresh with no new lines takes under 50 ms. (`KAKEIBO_BENCH=1 swift test -c release --filter realLogs`: 1.94 s / 29 ms.)
Status: done

### S-003 Fetch plan limits
As the user, Kakeibo shows my real Session, Weekly, and Fable limits, using the Claude Code login already on this Mac.
Screens: popover-dark.png, popover-signedout-dark.png, popover-offline-dark.png
Depends: S-002
Acceptance:
- [unit] Decodes Used % and Resets time for Session, Weekly, and Fable from the fixture response; a missing Fable limit shows as hidden, not 0%.
- [unit] Reads the OAuth token from Claude Code's Keychain item, never writes or logs it, and sends it only to Anthropic.
- [unit] No token → state `signedOut`; HTTP error or no network → state `offline` with the last snapshot.
- [self] Fetches at launch and every 5 minutes, and never more than once a minute.
Status: done
Note: checked live on 2026-11-23 with `--probe-limits`. The response's `limits` array has `session`, `weekly_all`, and a `weekly_scoped` limit for the model "Fable"; `five_hour` and `seven_day` are the fallback.
UX:
- States: signed out "Sign in to Claude Code to see your limits." with button "Open Terminal"; offline "Showing limits from 14:02. Unable to reach Anthropic." under the Gauges.

### S-004 See Session limit in the menu bar
As the user, I glance at the menu bar and see how much of my Session limit is Used.
Screens: menubar-light.png, menubar-dark.png
Depends: S-001, S-003
Acceptance:
- [snap] A small Gauge ring followed by "42%", in the menu bar's template color.
- [snap] At 90% or more the ring and number turn vermilion.
- [self] The width never changes between 9% and 100% (monospaced digits), so other menu bar icons don't jump.
Status: done
UX:
- Flow: glance -> click opens the popover.
- Surface: menu bar item.
- Words: tooltip "Kakeibo: Session 42% used, resets in 2 h 14 m".
- Access: VoiceOver "Kakeibo, Session limit 42% used".

### S-005 Open the popover and read the three Gauges
As the user, I click Kakeibo and see Session, Weekly, and Fable Gauges with when each Resets.
Screens: popover-light.png, popover-dark.png, popover-warning-dark.png
Depends: S-004
Acceptance:
- [snap] The large Session Gauge is on top with "42" in the center and "Session · Resets in 2 h 14 m" below. Weekly and Fable are two smaller Gauges in one row, each with "Resets Mon 09:00".
- [snap] At 90% or more, the Seal shows on that Gauge and a line reads "Session limit almost reached".
- [self] The countdown updates each minute while the popover is open.
Status: done
UX:
- Flow: click menu bar item -> popover -> Escape or click outside closes.
- Surface: popover (a few related readings tied to one control).
- States: loading shows the last snapshot; first launch with no snapshot shows empty Gauges and "Fetching limits…".
- Words: "Session", "Weekly", "Fable", "Resets in 2 h 14 m", "Session limit almost reached".
- Access: Tab moves Gauge → Gauge → buttons; each Gauge reads its full sentence (S-001).

### S-006 See today's Tokens and Cost
As the user, I see how many Tokens I used Today and what they would cost at API prices.
Screens: popover-dark.png
Depends: S-002, S-005
Acceptance:
- [snap] One card: "Today" with "1.24 M tokens" and "$18.40", and a caption "Estimated at API prices".
- [unit] 1,240,000 formats as "1.24 M"; 980 as "980"; cost under $0.01 as "<$0.01".
- [snap] Zero activity reads "No Claude Code activity today".
Status: done
UX:
- Surface: inline card in the popover.
- Words: hover on the cost: "Estimated from Claude Code logs at API prices. Your plan is not billed this amount."

### S-007 See Today by Project
As the user, I see which Projects used the most Tokens Today.
Screens: popover-dark.png
Depends: S-006
Acceptance:
- [snap] Up to three rows: Project name, a thin gold bar for its share, and Tokens. A fourth row "+2 more" shows when there are more.
- [snap] A long Project name truncates in the middle; hover shows the full path.
Status: done
UX:
- Surface: inline list in the popover.
- States: empty → the row hides; "+2 more" opens the Dashboard (S-010).
- Access: each row reads "Kakeibo, 412 thousand tokens, 33 percent of today".

### S-008 Refresh now
As the user, I make Kakeibo fetch limits and re-read logs right away.
Screens: popover-dark.png
Depends: S-005
Acceptance:
- [snap] The footer shows "Updated 14:02" and a Refresh button; while working, the button is replaced by a small spinner.
- [self] Command-R in the popover refreshes; a second press within a minute only re-reads logs.
Status: done
UX:
- Flow: Refresh button or Command-R -> spinner -> "Updated 14:07".
- Surface: inline footer button.
- Words: tooltip "Fetch limits and read new logs now (⌘R)".

### S-009 Keep the last reading across restarts
As the user, I open Kakeibo after a restart and see my last limits at once.
Screens: popover-offline-dark.png
Depends: S-003
Acceptance:
- [unit] Every LimitSnapshot is stored in SwiftData; the newest one loads before the first fetch.
- [self] Snapshots older than 90 days are deleted at launch.
Status: done

---

## M2 Dashboard: see where the tokens went

### S-010 Open the Dashboard
As the user, I open a window with all my usage from the popover.
Screens: dashboard-light.png, dashboard-dark.png, dashboard-empty-dark.png
Depends: S-005
Acceptance:
- [snap] "Dashboard…" in the popover footer opens one window (Command-D); a second click brings it forward.
- [snap] No logs at all: "No Claude Code Activity Yet" and "Kakeibo reads the logs in ~/.claude/projects." Never shown before the first read.
Status: done

### S-011 See Tokens by day
As the user, I see a bar chart of Tokens per day and switch between 7 and 30 days.
Screens: dashboard-dark.png
Depends: S-010
Acceptance:
- [snap] Gold bars, stacked by model, with a "7 Days | 30 Days" segmented control.
- [manual] Hovering a bar shows the date, Tokens, and Cost for each model.
Status: done

### S-012 See this week against last week
As the user, I compare this week's Tokens and Cost with last week's.
Screens: dashboard-dark.png
Depends: S-010
Acceptance:
- [snap] A card: "This week 8.1 M · $112" and "↑ 24% vs last week".
- [unit] Week starts on the locale's first weekday.
Status: done

### S-013 See the split by model
As the user, I see what share of Tokens each model used.
Screens: dashboard-dark.png
Depends: S-011
Acceptance:
- [snap] A horizontal split bar (Opus, Sonnet, Fable, Haiku) with percentages; the same model colors as S-011.
Status: done

### S-014 See every Project's totals
As the user, I see each Project's Tokens, Cost, and last activity in the selected range.
Screens: dashboard-dark.png
Depends: S-010
Acceptance:
- [snap] A list sorted by Tokens: name, Tokens, Cost, "2 hr ago", with the 7 Days | 30 Days range beside its title.
- [self] Clicking a column header sorts by it.
Status: done

### S-015 See Limit history
As the user, I see how Session and Weekly Used % moved over time.
Screens: dashboard-dark.png
Depends: S-009, S-010
Acceptance:
- [snap] A line chart of stored snapshots, with a dashed line at 100%, for the selected range.
Status: done

### S-016 See the activity heatmap
As the user, I see a year of daily activity as a grid.
Screens: dashboard-dark.png
Depends: S-010
Acceptance:
- [snap] 53 × 7 cells in five gold steps.
- [manual] Hovering a cell shows the date and Tokens.
- [snap] A Project menu above it ("All Projects") filters the grid to one Project.
Status: done

---

### S-017 See the Weekly limit by surface
As the user, I see how much of my Weekly limit went to Claude Code, Chats, Cowork, and Other.
Screens: overview-light.png, overview-dark.png
Depends: S-003, S-010
Acceptance:
- [unit] Decodes `seven_day_breakdown.rows` (name, share of use, share of limit) and `as_of`; a missing breakdown leaves the card hidden, not empty.
- [snap] A card on Overview titled "Weekly limit by surface" with "57% used" on the right. One row per surface, in the order Anthropic sends them, with a gold bar for its share of the limit and the text "53% of limit · 93% of use".
- [snap] A surface at 0% shows the row with an empty bar, so the list keeps the same rows from week to week.
- [snap] The caption "As of 2:10 AM · week started Thu 3:11 AM" (times in the Mac's format) sits under the rows.
Status: done
UX:
- Surface: inline card on the Overview page (information, no action).
- States: no breakdown (signed out or older response) → card hidden; a stale reading → the "As of" time says how old it is.
- Words: "Weekly limit by surface", "57% used", "53% of limit · 93% of use", "As of 01:46 · week started Fri 08:00". Surface names come from Anthropic ("Claude Code", "Chats", "Cowork", "Other").
- Access: each row reads "Claude Code, 53 percent of the Weekly limit, 93 percent of your use this week".

---

## M3 Summary: what did we do today?

### S-020 Summarize a Project's day
As the user, I press Summarize on a Project and get two lines from Claude about what we did.
Screens: summary-dark.png
Depends: S-014
Acceptance:
- [unit] The digest holds only Today's user prompts (first 200 chars each), touched file names, and git commits, capped at 6,000 tokens.
- [self] Runs `claude -p --model haiku` off the main thread; the row shows a spinner and Cancel.
- [snap] The Summary shows under the Project row with "Summarized 14:20 · 4.1 k tokens".
Status: todo

### S-021 Keep and redo a Summary
As the user, I see the last Summary again later and can run it again.
Screens: summary-dark.png
Depends: S-020
Acceptance:
- [unit] Summaries are stored per Project and day.
- [snap] An existing Summary shows a "Summarize Again" button.
Status: todo

### S-022 Explain when Summarize can't run
As the user, I'm told why Summarize failed and how to fix it.
Screens: summary-dark.png
Depends: S-020
Acceptance:
- [unit] `claude` not found → "Unable to find Claude Code. Install it, then try again."
- [unit] Limit reached or a non-zero exit → the CLI's first error line, and the button stays enabled.
Status: todo

---

## M4 Alerts

### S-030 Alert at 80% and 90%
As the user, I get an Alert when any limit reaches 80% and again at 90%.
Screens: settings-dark.png
Depends: S-003
Acceptance:
- [unit] Each threshold alerts once per limit per reset period.
- [manual] The Alert reads "Session limit 90% used · Resets in 38 m".
Status: todo

### S-031 Alert when a limit resets
As the user, I get an Alert when a limit I'd pushed past 80% resets.
Depends: S-030
Acceptance:
- [unit] Fires only if the limit was at 80% or more before the reset.
- [manual] "Session limit reset. You're back to 0%."
Status: todo

### S-032 Get a daily numbers Alert
As the user, I get one Alert at the end of the day with Tokens, Cost, and the top Project.
Depends: S-006
Acceptance:
- [unit] Fires at the time set in Settings (default 21:00), only on days with activity.
- [manual] "Today: 1.24 M tokens · $18.40 · mostly Kakeibo".
Status: todo

### S-033 Turn each Alert on or off
As the user, I choose which Alerts Kakeibo sends.
Screens: settings-light.png, settings-dark.png
Depends: S-030, S-031, S-032
Acceptance:
- [snap] Settings > Alerts: three toggles and the daily time picker.
- [self] Notification permission is requested the first time a toggle is turned on, not at launch.
Status: todo

---

## M5 Settings and polish

### S-040 Choose what the menu bar shows
As the user, I pick what Kakeibo shows in the menu bar.
Screens: settings-dark.png, menubar-dark.png
Depends: S-004
Acceptance:
- [snap] Settings > General > Menu Bar: "Gauge Only", "Session %", "Session + Weekly", "Session + Fable".
- [snap] Each choice has a menubar snapshot variant.
Status: todo

### S-041 Launch at login
As the user, I have Kakeibo start when I log in.
Screens: settings-dark.png
Acceptance:
- [self] Settings > General > "Open at Login" uses `SMAppService.mainApp`; the toggle reflects the real state.
Status: todo

### S-042 Set how often to refresh
As the user, I choose how often limits are fetched.
Screens: settings-dark.png
Depends: S-003
Acceptance:
- [snap] "Refresh every" 1, 5, 15 minutes; default 5.
Status: todo

### S-043 App icon with the 家 Seal
As the user, I see Kakeibo's own icon in the Dock and Settings.
Acceptance:
- [snap] An Icon Composer icon: open gold ensō on lacquer with the vermilion 家 Seal, reviewed in every look.
Status: todo

### S-044 Quit
As the user, I quit Kakeibo from the popover.
Screens: popover-dark.png
Acceptance:
- [snap] Footer reads "Dashboard…  Settings…  Quit Kakeibo", like Hachibu.
- [self] Command-Q in the popover quits.
Status: todo

---

## Later
- Project cards with sparklines
- A timeline of today per Project (prompts, files, branch)
- Live sessions running now
- Automatic Summaries with the daily Alert
- Open a Project in Finder, Terminal, or VS Code

## Dropped
- Accounts and sign-in inside Kakeibo: it reuses the Claude Code login.
- Sync across Macs: one Mac for now (later: iCloud sync).
- Sharing or exporting usage reports: one user.
- Real billing data: plans aren't billed per token; Cost stays an estimate.
- Claude.ai web and desktop app usage beyond what the limits already show: no local logs exist for them.
