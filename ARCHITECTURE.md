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

## Threading
Log parsing runs in the `UsageStore` actor, files in a task group. Network uses URLSession async.
Everything else is main actor.

## Test seams
`APP_STORE` in /tmp switches to fixture limits (`APP_LIMITS`) and fixture logs (`/tmp/Kakeibo-logs`,
written by `SeedData.writeLogs`). Self-test: `tools/selftest.sh`. Snapshots: `tools/snap.sh`.
