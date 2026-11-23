# Fix log

## Snapshot runs stalled for minutes
Symptom: `tools/snap.sh` sat 9+ minutes between pages, or wrote nothing.
Cause: startup ran only from the menu bar label's `.task`, which never runs if the
menu bar has no room to draw the item. App Nap also stretched a background
app's `Task.sleep`. (The Mac's load average was also 47 from system daemons, which
made it worse.)
Fix: test runs (APP_STORE set) open the Dashboard, whose `.task` also calls
`Startup.run` (once). Snapshot mode holds a `beginActivity(.userInitiated, .latencyCritical)`.
Rule: never start app work only from a menu bar label; give test modes a window that always appears.

## Snapshots caught the wrong window or a thumbnail
Symptom: settings-*.png showed the Dashboard; some PNGs were Stage Manager's small tilted thumbnail.
Cause: windows were found by title, but the Dashboard's title follows its page ("Projects").
Stage Manager sometimes hands screencapture its strip thumbnail.
Fix: find windows by their SwiftUI identifier (scene id prefix, "Settings" for Settings), and
retry a capture narrower than the window's backing width.
Rule: never find a SwiftUI window by title; check each capture's pixel width.

## The Dashboard flashed "No Claude Code Activity Yet"
Symptom: the Overview showed its empty state for a moment before the charts.
Cause: the empty state checked "logs were read" (service-wide) while the page's own data had not loaded yet.
Fix: `DashboardData.loaded`; the empty state needs loaded && no activity.
Rule: decide an empty state from the view's own loaded data, never from a global "has read" flag.

## Summarize said "Claude Code gave no answer" instead of the real error
Symptom: when Claude Code failed (limit reached, not logged in), the row showed a generic message.
Cause: an empty stdout was parsed into a generic error, which won over stderr's first line.
Fix: `SummaryReply.parse` returns no error for empty output; the caller then uses stderr.
Rule: when a CLI fails, show stderr's own words unless stdout carries a structured error.

## The first test Alert was refused
Symptom: `--test-alert` printed "not allowed"; `requestAuthorization` failed with "Notifications are not allowed for this application".
Cause: the first permission prompt was dismissed or declined, so macOS marked Kakeibo as denied and never asks again.
Fix: the user turned on "Allow notifications" for Kakeibo in System Settings > Notifications; Settings > Alerts shows
"Open Notifications…" when permission is denied, and "Send Test Alert" checks the path end to end.
Rule: after a denied notification prompt, send people to System Settings; the app can't ask again.

## Reset times read 4:52 PM as "04:52"
Symptom: "Resets Thu 04:52" for a weekly reset at 4:52 PM, in the popover, Dashboard, Alerts, and CLI.
Cause: `ResetText.short` formatted the hour as two digits with AM/PM omitted, which is a 12-hour clock.
Fix: use the Mac's own time style (`.hour().minute()`), so it reads "Thu 4:52 PM" (or "Thu 16:52").
Rule: never omit AM/PM from a 12-hour time; use the locale's time style instead of a fixed pattern.

## The popover opened with a focus ring on "+2 more"
Symptom: a blue focus ring around the first button in the popover as soon as it opened (seen in the README hero).
Cause: the popover's window made its first focusable control key on open.
Fix: `.noInitialFocus()` on `PopoverView`, like every other window; Tab still moves focus.
Rule: every window and popover opens with no initial focus.

## "Your Claude Code login expired. Run claude in Terminal…" after every quiet stretch
Symptom: after hours without Claude Code (overnight), the popover said the login expired and offered Open Terminal.
Cause: Claude Code's access token lasts about 8 hours and only Claude Code renews it, when it runs. Kakeibo read
an expired token as a lost login. The login itself was fine; signing in again was never needed.
Fix: on an expired token (or a 401), Kakeibo runs `claude auth status` (no tokens spent, at most every 10 minutes)
and reads the Keychain again. Until it is renewed it keeps the last reading and says limits update when Claude Code
runs; Open Terminal is only for a real sign-out. Settings shows "Waiting for Claude Code".
Rule: tell an expired token apart from a sign-out; never send people to sign in when the app that owns the login renews it.
