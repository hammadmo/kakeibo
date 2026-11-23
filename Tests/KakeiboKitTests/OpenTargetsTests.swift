import Testing
@testable import KakeiboKit

@Test func onlyInstalledAppsAreListedFinderFirst() {
    let installed: Set<String> = ["com.apple.Terminal", "com.mitchellh.ghostty", "com.apple.dt.Xcode"]
    let targets = OpenTarget.available { installed.contains($0) }
    #expect(targets.finder.title == "Open in Finder")
    #expect(targets.terminals.map(\.name) == ["Terminal", "Ghostty"])
    #expect(targets.editors.map(\.name) == ["Xcode"])
    #expect(OpenTarget.available { _ in false }.editors.isEmpty)
}
