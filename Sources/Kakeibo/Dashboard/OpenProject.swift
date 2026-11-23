import AppKit
import KakeiboKit
import SwiftUI

/// Opens a Project's folder in Finder, a terminal, or an editor (S-061).
@MainActor
enum ProjectOpener {
    static var targets: (finder: OpenTarget, terminals: [OpenTarget], editors: [OpenTarget]) {
        OpenTarget.available { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    static func canOpen(_ path: String) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isFolder) && isFolder.boolValue
    }

    static func open(_ path: String, in target: OpenTarget) {
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        guard target != .finder, let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.id) else {
            NSWorkspace.shared.open(folder)
            return
        }
        NSWorkspace.shared.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// The menu items, shared by the "Open ▾" pull-down and context menus.
struct OpenProjectItems: View {
    let path: String

    var body: some View {
        let targets = ProjectOpener.targets
        let exists = ProjectOpener.canOpen(path)
        Group {
            item(targets.finder)
            if !targets.terminals.isEmpty {
                Divider()
                ForEach(targets.terminals) { item($0) }
            }
            if !targets.editors.isEmpty {
                Divider()
                ForEach(targets.editors) { item($0) }
            }
            if !exists {
                Divider()
                Text("This folder no longer exists")
            }
        }
        .disabled(!exists)
    }

    private func item(_ target: OpenTarget) -> some View {
        Button(target.title) { ProjectOpener.open(path, in: target) }
    }
}

/// "Open ▾" beside a Project's name, in the kit's pull-down look.
struct OpenProjectMenu: View {
    let path: String

    var body: some View {
        Menu {
            OpenProjectItems(path: path)
        } label: {
            HStack(spacing: Space.xs) {
                Text("Open")
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .kitType(.labelStrong)
            .foregroundStyle(Ink.accentText)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Open this Project's folder")
        .accessibilityLabel("Open \((path as NSString).lastPathComponent) in…")
    }
}
