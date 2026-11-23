import AppKit
import Observation
@preconcurrency import Sparkle

/// Checks for a newer version of Kakeibo, and installs it, with Sparkle
/// (the same setup as Hachibu).
///
/// It reads one feed file (`SUFeedURL` in Info.plist) and, when the person
/// agrees, downloads the new version; each download is checked against the
/// public key in Info.plist (`SUPublicEDKey`) before it is installed. Nothing
/// about the Mac is sent. Test runs, the CLI, and one-shot runs never check.
@Observable
final class Updates: NSObject {
    static let shared = Updates()

    /// A newer version a background check found and has not shown yet. The
    /// popover offers it, so nothing pops up while the person works elsewhere.
    private(set) var availableVersion: String?
    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    /// False for test runs, one-shot runs, and a copy built without a feed.
    static var canUpdate: Bool {
        let oneShot = ["--selftest", "--probe-limits", "--test-alert"].contains { CommandLine.arguments.contains($0) }
        return !Store.isOverridden && !oneShot && Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
    }

    /// The version this copy is.
    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    func start(automatic: Bool) {
        guard Self.canUpdate, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        controller.updater.automaticallyChecksForUpdates = automatic
        controller.startUpdater()
        self.controller = controller
    }

    /// "Check for Updates…": asks now and shows the answer, whatever it is.
    func check() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    func setAutomatic(_ isOn: Bool) {
        controller?.updater.automaticallyChecksForUpdates = isOn
    }
}

extension Updates: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle shows what a background check found by itself only right after
    /// launch or when the Mac has been idle. Otherwise the popover offers it.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                                          andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        let version = update.displayVersionString
        Task { @MainActor in self.availableVersion = version }
    }

    // The popover keeps offering the update until it is installed or turned
    // down: Kakeibo has no Dock icon, so an update window that went behind
    // another app could not be found again otherwise.

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.availableVersion = nil }
    }
}
