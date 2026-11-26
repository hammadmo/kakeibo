import AppKit
import KakeiboKit
import SwiftUI
import UserNotifications

/// The picture beside an Alert: the ensō Gauge on black lacquer, in gold (or
/// vermilion with the 家 Seal at 90%). macOS draws the notification itself and
/// lets no app change its colors; this image is the part Kakeibo can style.
@MainActor
enum AlertArt {
    /// What the picture shows for each Alert.
    static func gauge(for event: AlertEvent) -> (percent: Int?, warning: Bool) {
        switch event {
        case .almostReached(_, _, let used, _): (Int(used.rounded()), Used(used).isAlmostReached)
        case .reset: (0, false)
        case .daily: (nil, false)
        }
    }

    static func view(percent: Int?, warning: Bool) -> some View {
        ZStack {
            Ink.surface
            if let percent {
                EnsoGauge(percent: percent, tone: warning ? .warning : .normal, size: Metric.gaugeSize,
                          showsSeal: warning, label: "Limit")
            } else {
                // The seal at its own size, scaled up whole, so 家 grows with it.
                SealMark()
                    .rotationEffect(.degrees(-5))
                    .scaleEffect(Metric.gaugeSize * 0.5 / Metric.sealSize)
            }
        }
        .frame(width: Metric.gaugeSize + Space.xxl * 2, height: Metric.gaugeSize + Space.xxl * 2)
        .environment(\.colorScheme, .dark)
    }

    /// A PNG of the picture, in a new file each time (the notification
    /// system moves the file into its own store).
    static func png(percent: Int?, warning: Bool) -> URL? {
        var result: URL?
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view(percent: percent, warning: warning))
            renderer.scale = 2
            guard let tiff = renderer.nsImage?.tiffRepresentation,
                  let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            let url = FileManager.default.temporaryDirectory.appending(path: "kakeibo-alert-\(UUID().uuidString).png")
            if (try? data.write(to: url)) != nil { result = url }
        }
        return result
    }

    static func attachment(for event: AlertEvent) -> UNNotificationAttachment? {
        let gauge = gauge(for: event)
        return attachment(percent: gauge.percent, warning: gauge.warning)
    }

    static func attachment(percent: Int?, warning: Bool) -> UNNotificationAttachment? {
        guard let url = png(percent: percent, warning: warning) else { return nil }
        return try? UNNotificationAttachment(identifier: "gauge", url: url, options: nil)
    }
}
