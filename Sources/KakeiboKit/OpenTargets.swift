import Foundation

/// Where a Project's folder can open (S-061): Finder, then each installed
/// terminal, then each installed editor, in this fixed order.
public struct OpenTarget: Equatable, Sendable, Identifiable {
    /// The app's bundle identifier; Finder is "com.apple.finder".
    public let id: String
    public let name: String
    public var title: String { "Open in \(name)" }

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static let finder = OpenTarget(id: "com.apple.finder", name: "Finder")
    public static let terminals = [
        OpenTarget(id: "com.apple.Terminal", name: "Terminal"),
        OpenTarget(id: "com.googlecode.iterm2", name: "iTerm"),
        OpenTarget(id: "com.mitchellh.ghostty", name: "Ghostty"),
        OpenTarget(id: "dev.warp.Warp-Stable", name: "Warp"),
    ]
    public static let editors = [
        OpenTarget(id: "com.microsoft.VSCode", name: "VS Code"),
        OpenTarget(id: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        OpenTarget(id: "dev.zed.Zed", name: "Zed"),
        OpenTarget(id: "com.apple.dt.Xcode", name: "Xcode"),
    ]

    /// Finder always, then the installed terminals and editors.
    public static func available(installed: (String) -> Bool) -> (finder: OpenTarget, terminals: [OpenTarget], editors: [OpenTarget]) {
        (finder, terminals.filter { installed($0.id) }, editors.filter { installed($0.id) })
    }
}
