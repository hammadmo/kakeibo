---
name: kakeibo
description: Ask the Kakeibo app on this Mac about Claude usage with the `kakeibo` command: today's tokens and estimated cost, the Session, Weekly, and Fable limits and when they reset, this week against last, tokens per day by model, every Project's totals, and Haiku summaries of a Project's day. Use when the user asks how much Claude they used, how close they are to a limit, which project used the most, or names Kakeibo.
---

# Kakeibo

`kakeibo` reads from the running Kakeibo app (a menu bar app). If it is closed,
the command opens it in the background. Numbers come from Claude Code's own logs
on this Mac and from the user's plan limits at Anthropic.

## Rules

- Always add `--json` and read the JSON. Exit 0 is ok; otherwise read
  `error.code` and `error.message`, and do what the message says.
- Cost (`costUSD`) is an estimate at API prices, not a bill. Say so when you report it.
- `summarize` spends a few thousand tokens of the user's plan. Without `--yes` it only
  explains that; ask the user before running it again with `--yes`.
- Projects are named by folder (`Kakeibo`) or full path. `kakeibo today` lists today's.
- To try commands without real data: `APP_STORE=/tmp/kakeibo-test.store kakeibo ...`.

## Main commands

| Command | Does |
| --- | --- |
| `kakeibo limits --json` | Session, Weekly, Fable: `usedPercent`, `resetsAt`; Weekly by surface |
| `kakeibo today --json` | Today's tokens, cost, and busiest Projects |
| `kakeibo week --json` | This week vs the same point last week (`changePercent`) |
| `kakeibo projects --days 30 --sort cost --json` | Every Project's tokens, cost, last activity |
| `kakeibo days --days 7 --json` | Tokens and cost per day, by model family |
| `kakeibo summary <project> --json` | Today's Summary of a Project, if any |

Everything else: `kakeibo help`, and `kakeibo help <command>` for its options.
