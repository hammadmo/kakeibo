# Changelog

## 0.3.3
- Fixed: limits stopped updating about 8 hours after you last ran `claude` in Terminal ("Showing limits from 8:32 AM…"), even while you used Claude Code in the desktop app. When Claude Code's token expires, Kakeibo now has Claude Code renew it with one tiny Haiku call (about 1,000 tokens, at most every 30 minutes), so limits keep updating, overnight included.

## 0.3.2
- Fixed: after a few quiet hours Kakeibo said your Claude Code login had expired and asked you to sign in in Terminal. Only Claude Code's short-lived token had expired, and signing in was never needed. Kakeibo now asks Claude Code to renew it (no tokens spent), keeps showing your last reading, and says limits update the next time Claude Code runs. Open Terminal appears only when you have really signed out.

## 0.3.1
- `kakeibo live`: Claude Code sessions that replied in the last 5 minutes, with their tokens.
- `kakeibo timeline`: today's sessions per project, with times, branch, the first prompt, and the prompts and files changed. Add `--project` for one project.
- `kakeibo project open <project>`: open a project's folder in Finder, or with `--in` in an installed terminal or editor.
- The same three are tools in Kakeibo's MCP server.

## 0.3
- Summarize my day (Settings > Alerts, off by default): before the daily Alert, Kakeibo summarizes your three busiest projects with Haiku and puts the first Summary in the Alert. It uses a few thousand tokens of your plan for each.
- Open a project in Finder, your terminal (Terminal, iTerm, Ghostty, Warp), or your editor (VS Code, Cursor, Zed, Xcode): the Open menu on the Today page, or the context menu of a project on the Projects page.

## 0.2.1
- Fixed: the popover opened with a focus ring around its first button ("+2 more"). It now opens calm; Tab still moves through the buttons.

## 0.2
- The Dashboard opens on your usage: Session, Weekly, and Fable gauges with when each resets, and today's tokens, estimated cost, replies, projects, and live sessions.
- A Today page: each project's sessions today, with times, branch, the first prompt, and how many prompts and files.
- Live now in the popover: Claude Code sessions that replied in the last 5 minutes, with their tokens.
- The Projects page opens with the six busiest projects as cards, each with a 14-day line; click one to see its activity.
- Fixed: reset times a few days away read 4:52 PM as "04:52". They now follow your Mac's clock.
- `kakeibo open today` opens the new page.

## 0.1
- Menu bar ensō for the Session limit, with Weekly and Fable in the popover.
- Today's tokens and estimated cost from Claude Code's logs, and the busiest Projects.
- Dashboard: tokens by day and model, this week vs last, Weekly limit by surface, limit history, a year of activity, every Project's totals.
- Summarize a Project's day with Haiku.
- Alerts at 80% and 90%, on reset, and with the daily numbers.
- `kakeibo` CLI and MCP server.
