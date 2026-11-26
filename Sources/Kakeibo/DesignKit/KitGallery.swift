import AppKit
import SwiftUI

/// Every kit part in its states, for snapshots (kit-gallery-light/dark.png).
struct KitGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Text("Kakeibo kit").kitType(.title).foregroundStyle(Ink.text)

            section("Gauge") {
                HStack(spacing: Space.lg) {
                    gauge(nil)
                    gauge(0)
                    gauge(42)
                    gauge(63)
                    gauge(92)
                    gauge(100)
                }
            }

            section("Seal") {
                HStack(spacing: Space.md) {
                    SealMark()
                    SealMark(size: Metric.sealSmall)
                }
            }

            section("Card") {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Today").kitType(.label).foregroundStyle(Ink.textSoft)
                    Text("1.24 M tokens").kitType(.numeral).foregroundStyle(Ink.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .kitCard()
            }

            section("Buttons") {
                HStack(spacing: Space.sm) {
                    Button("Dashboard…") {}.buttonStyle(.kit())
                    Button("Settings…") {}.buttonStyle(.kit(.secondary))
                    Button("Quit Kakeibo") {}.buttonStyle(.kit(.ghost))
                }
                .fixedSize()
            }
        }
        .padding(Space.xxl)
        .frame(width: 840, alignment: .leading)
        .background(Ink.surface)
    }

    private func gauge(_ percent: Int?) -> some View {
        let warning = (percent ?? 0) >= 90
        return EnsoGauge(percent: percent, tone: warning ? .warning : .normal,
                         size: Metric.gaugeSmall, showsSeal: warning, label: "Session limit")
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title).kitType(.section).foregroundStyle(Ink.textSoft)
            content()
        }
    }

    /// The Alert pictures (AlertArt): 92% warning, a reset, and the daily seal.
    static func renderAlertArt(to dir: String) {
        for (name, percent, warning) in [("alert-art-92", Optional(92), true), ("alert-art-reset", Optional(0), false),
                                         ("alert-art-daily", nil, false)] {
            guard let url = AlertArt.png(percent: percent, warning: warning) else { continue }
            let path = "\(dir)/\(name).png"
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.moveItem(at: url, to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path)")
        }
    }

    /// Renders the gallery offscreen in light and dark. No window is needed:
    /// the kit draws no glass or materials.
    static func render(to dir: String) {
        for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let appearance = NSAppearance(named: name)!
            appearance.performAsCurrentDrawingAppearance {
                let renderer = ImageRenderer(content: KitGallery()
                    .environment(\.colorScheme, mode == "dark" ? .dark : .light))
                renderer.scale = 2
                guard let image = renderer.nsImage,
                      let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                else { return }
                let path = "\(dir)/kit-gallery-\(mode).png"
                try? png.write(to: URL(fileURLWithPath: path))
                print("SNAPSHOT \(path)")
            }
        }
    }
}
