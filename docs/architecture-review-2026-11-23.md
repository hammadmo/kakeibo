# Architecture review, 2026-11-23 (end of M1)

Survey: 3,100 lines of Swift, largest file 301 (`DesignKit/EnsoGauge.swift`), no file over 600,
no drifted `private struct` copies. Two fix-log entries, both in snapshot tooling.
Parsing and pricing live in `KakeiboKit` with unit tests; app types are `@MainActor`
and do their slow work in the `UsageStore` actor.

## Two design systems side by side  [Done 2026-11-23, approved by the user]

Files: Sources/Kakeibo/UI/Theme.swift (144), UI/AppearanceSettings.swift (165), DesignKit/*, CLAUDE.md
Signal: a page lives far from its feature; rules contradict the brief.
Problem: the template's accent picker (`Theme`, Settings > Appearance) still ships, but the
popover and menu bar use Hachibu's `Ink` kit. The Dashboard and Settings still look like the
template. A new Dashboard card has to pick one of two token sets.
Proposal: drop `Theme`/`AppearanceSettings`. Dashboard and Settings use `Ink`, `KitType`, and
`kitCard()`, plus `.kitWindow(width:)` from Hachibu (copy `KitWindow.swift`).
Benefits: one token set; M2 cards are built once.
Proof of same behavior: popover and kit snapshots unchanged; Dashboard and Settings change on purpose,
so this is a design change for the user to approve, not a refactor.
Plan: 1) copy KitWindow, 2) restyle Settings, 3) delete Theme + Appearance tab, 4) restyle Dashboard in M2.

## Limits behind a seam  [Worth exploring]

Files: Sources/Kakeibo/Limits/LimitsService.swift (181)
Signal: a dependency cannot be replaced in a test.
Problem: the Keychain read, the HTTP call, storage, and fixtures sit in one `@MainActor` class;
fixtures are a `switch` inside it. S-030 (Alerts at 80/90%) needs sequences of readings to test.
Proposal:
```swift
protocol LimitsSource: Sendable { func fetch() async -> LimitsResult }  // .ok(Limits) .signedOut .expired .offline(String)
struct AnthropicLimitsSource: LimitsSource { ... }   // Keychain + URLSession
struct FixtureLimitsSource: LimitsSource { ... }     // tests, snapshots
```
Benefits: Alerts get tested with scripted readings; the service shrinks to timing + storage.
Proof: the 13 self-test checks and the popover snapshots stay the same.
Plan: 1) add the protocol and both sources, 2) move the service over, 3) delete the fixture switch.
Best done at the start of M4 (Alerts), when it pays for itself.

## Top recommendation

None to do unattended: no card is Strong. Decide the design-system card before M2, since every
Dashboard card depends on it.

## Considered, not recommended
- Splitting `SelfTest.swift`: 100 lines, fine.
- Moving `SeedData.writeLogs` into KakeiboKit: it's test fixture code and only the app uses it.

## M2 check-in (same day)
4,100 lines; largest files `EnsoGauge.swift` (301) and `Dashboard/OverviewPage.swift` (285). No new signals.
Dashboard data is read once per range/version through `UsageService.dashboard(range:)` from the actor.
Still open: "Limits behind a seam", which is due at the start of M4 (Alerts).
