import AppKit
import KakeiboKit

/// `Kakeibo --probe-limits` fetches the real limits once and prints the window
/// keys and Used values (never the token), then quits. It checks the decoder
/// against the live response, which is not documented.
@MainActor
enum LimitsProbe {
    static var requested: Bool { CommandLine.arguments.contains("--probe-limits") }

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        Task {
            await model.limits.fetch(force: true)
            print("PROBE status \(model.limits.status)")
            if let login = ClaudeLogin.read() {
                print("PROBE login expires \(login.expiresAt?.description ?? "nil") (now \(Date.now))")
            } else {
                print("PROBE no login in the Keychain")
            }
            if let limits = model.limits.current {
                print("PROBE keys \(limits.keys.joined(separator: ", "))")
                for (name, window) in [("session", limits.session), ("weekly", limits.weekly), ("fable", limits.fable)] {
                    print("PROBE \(name) \(window.map { "\($0.used)% resets \($0.resets?.description ?? "nil")" } ?? "absent")")
                }
            }
            NSApp.terminate(nil)
        }
    }
}
