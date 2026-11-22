# Kakeibo design kit

Kakeibo uses Hachibu's kit (`~/mac battery app/Hachibu/design/KIT.md`): the same
Pigment and Ink tokens, type, metrics, motion, ensō Gauge, and buttons.
`DesignKit/Tokens.swift`, `EnsoGauge.swift`, and `Buttons.swift` are copied from
Hachibu. Change them there first, then copy them here, so the family stays one look.

Differences from Hachibu:
- The Seal bears 家 (house, from 家計簿 kakeibo), not 八.
- The Seal shows only when a limit is almost reached (90% or more). It's off by default.
- The Gauge has no limit dot. Its VoiceOver label is the limit's name ("Session limit"),
  and its value reads "42% used, resets in 2 hours 14 minutes", plus "almost reached" at 90% or more.
- `Metric.menuBarGauge` (14 pt) is the ring in the menu bar item.
- Cards follow Jubako's raised lacquer grid: `kitCard()`.

Gallery: `APP_SNAPSHOT_PAGES=kit tools/snap.sh` writes `kit-gallery-light.png` and `kit-gallery-dark.png`.

Windows: the Dashboard (width 760) and Settings (width 520) use Hachibu's `kitWindow` frame
(`KitWindow.swift`, `Motifs.swift`: wave band and plum sprig) and `KitTabBar` (`Controls.swift`).
The template's accent picker was removed on 2026-11-23.
