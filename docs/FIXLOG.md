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
