# Architecture review, 2026-11-26 (after login renewal and Alert pictures)

Survey: 6,850 lines of Swift (up 90 since 2026-11-24). Since that review, seven files changed once or twice each:
`LimitsService`, `ClaudeCLI`, `AlertService`, the new `AlertArt`, `KitGallery`, `Snapshot`, and `SelfTest`. Largest files
are unchanged (`EnsoGauge.swift` 301, `OverviewPage.swift` 286); `SelfTest.swift` is 248 lines with 37 checks. No
copied `private struct`s. Fix log: 13 entries. Claude Code's login now appears twice (the misleading "expired" message,
then limits freezing for 9 hours) and notifications twice (the refused first prompt, the cached icon). No area has three.

Result: nothing Strong. The code is in good shape for its size; the two cards below are for later.

## Claude Code's login behind a seam  [Worth exploring]

Files: Sources/Kakeibo/Limits/LimitsService.swift (223), Sources/Kakeibo/ClaudeCode/ClaudeCLI.swift (renewLogin)
Signal: the same area in two fix-log entries; the Keychain cannot be replaced in a test.
Problem: `LimitsService.fetch` reads the Keychain, decides expired vs signed out, renews, re-reads, and calls Anthropic.
The self-test covers only the renewal throttle, not that flow. Both bugs, though, came from wrong guesses about
Claude Code (which program renews the token, and what `claude auth status` does), which no fake would have caught.
Real expiries proved the fix.
Proposal:
```swift
protocol ClaudeLoginSource { func read() -> ClaudeLogin?; func renew() async }   // Keychain + ClaudeCLI, or a fixture
// LimitsService(container:, login: some ClaudeLoginSource)
// Self-test: expired → renewed → fetched; expired → still expired → last reading kept; 401 → renewed once.
```
Benefits: the expired, renewed, and signed-out paths get self-test checks; `fetch` gets shorter.
Proof: the 37 self-test checks, `kakeibo limits` against the real login, and `--probe-limits` give the same results.
Plan: 1) add the protocol with the Keychain adapter, 2) move `fetch` over, 3) add the fixture adapter and three checks.
Do it if the login logic changes again.

## One reader for Claude Code log lines  [Worth exploring, unchanged]

As in docs/architecture-review-2026-11-24.md: `Digest` and `Timeline` still repeat the changed-file loop.
No third reader has appeared.

## Considered, not recommended
- `KitGallery.renderAlertArt`: a snapshot helper in the design kit's gallery file. It renders kit parts, so it fits
  there well enough; move it beside `AlertArt` if the gallery file grows.
- `AlertArt` renders on the main actor: it draws one small image per Alert, a few times a day.
- `SelfTest.swift` split: still under 300 lines; split at about 400 (see the 2026-11-24 review).

## Top recommendation

None now. If the login logic changes again, do "Claude Code's login behind a seam" first.
