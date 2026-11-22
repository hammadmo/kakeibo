# Kakeibo

A menu bar ledger of my Claude usage: plan limits, tokens, cost, and what each project did, in the Hachibu / Jubako look. For one user: me.

Bundle id: `app.kakeibo.mac` (decided by the agent, matches `app.hachibu.mac`).

## Replaces
Running `/usage` in Claude Code and guessing how close I am to the limits.

## Main jobs
1. Glance at the menu bar: how much of my 5-hour session / weekly / Fable limit is used, and when it resets.
2. Open the dashboard: daily and weekly tokens and cost, split by model and by project, with charts.
3. Ask "what did we do today in this project?" and get a two-line Claude summary on a button press.

## Data
- **LimitSnapshot**: time, session %, session reset, weekly all-models %, weekly reset, weekly Fable %, Fable reset. Fetched from Anthropic with the Claude Code login already on this Mac.
- **UsageEvent** (read from `~/.claude/projects/**/*.jsonl`, not copied): time, project, session id, model, input / output / cache tokens, estimated cost.
- **Project**: path, name, last active, tokens and cost today / this week.
- **Summary**: project, day, text, tokens it cost.

## Shape
Menu bar item + popover for the glance, plus a dashboard window. macOS 26 or later.
Local data. Needs the internet only for the limits and the AI summary. No accounts.

- **Menu bar item**: what it shows is set in Settings (ring only, session %, session + weekly, …).
- **Popover**: ensō gauges for session, weekly, and Fable with reset countdowns, today's tokens and cost, a "today by project" strip, and Open Dashboard / Settings / Quit.
- **Dashboard window**: daily / weekly / 30-day charts, model split, per-project list with token and cost totals, activity heatmap, and a "Summarize today" button for each project.

## System hooks
Menu bar item, launch at login, notifications:
- at 80% and 90% of any limit
- when a limit resets
- a daily summary at the end of the day (numbers only, no AI)

AI summary: runs `claude -p` with Haiku **only when I press the button**. It sends a condensed digest (my prompts, files touched, commits), about 3–6k tokens for each project, and shows what it cost.

## Reference
My own apps: Hachibu (`~/mac battery app/Hachibu`, `design/KIT.md`) and Jubako (`~/Projects/vorssaint`).

## Look
Own parts in the Hachibu / Jubako family: ink on warm paper (light), gold on black lacquer (dark), the open ensō brush ring as the gauge, a vermilion seal as the only bright color, and Jubako's raised card grid and gold charts. The seal bears **家**. Reuse Hachibu's tokens; build with `design-kit`.

## Not in version one
- Per-project cards with sparklines, a timeline of today, and live sessions (later, if the summary proves useful)
- Automatic or scheduled AI summaries
- iCloud sync and more than one Mac
