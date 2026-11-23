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
