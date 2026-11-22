import SwiftUI

/// A switch. Off is an outlined track; on is a filled one.
///   Toggle("Open at login", isOn: $on).toggleStyle(.kit)
struct KitToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        KitToggleBody(configuration: configuration)
    }
}

extension ToggleStyle where Self == KitToggleStyle {
    static var kit: KitToggleStyle { KitToggleStyle() }
}

private struct KitToggleBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.forcedPartState) private var forced
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool
    @State private var hovering = false
    @State private var pressing = false

    private var state: PartState {
        forced ?? (!isEnabled ? .disabled : pressing ? .pressed : hovering ? .hover : focused ? .focused : .rest)
    }

    var body: some View {
        let isOn = configuration.isOn
        let inset = (Metric.toggleHeight - Metric.toggleThumb) / 2
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(isOn ? Ink.fill : state == .hover || state == .pressed ? Ink.wash : .clear)
                .overlay(Capsule().strokeBorder(isOn ? .clear : Ink.outline, lineWidth: Metric.hairline))
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Ink.onFill : Ink.textSoft)
                        .frame(width: Metric.toggleThumb, height: Metric.toggleThumb)
                        .scaleEffect(state == .pressed ? 0.88 : 1)
                        .padding(inset)
                }
                .overlay {
                    if state == .focused {
                        Capsule().inset(by: -Metric.focusRing * 2)
                            .strokeBorder(Ink.accent, lineWidth: Metric.focusRing)
                    }
                }
                .frame(width: Metric.toggleWidth, height: Metric.toggleHeight)
                .opacity(isOn && state == .hover ? 0.88 : 1)
                .contentShape(Capsule())
        }
        .buttonStyle(PressReporting(pressing: $pressing))
        .focused($focused)
        .opacity(state == .disabled ? 0.4 : 1)
        .animation(Motion.press, value: isOn)
        .animation(Motion.hover, value: state)
        .onHover { hovering = $0 && !Snapshot.isRunning }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// A plain button style that reports whether it is pressed.
private struct PressReporting: ButtonStyle {
    @Binding var pressing: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, now in pressing = now }
    }
}

/// Text tabs with a gold underline under the selected one. Left and right
/// arrow keys move between tabs.
struct KitTabBar<Tab: Hashable>: View {
    var tabs: [(id: Tab, title: String)]
    @Binding var selection: Tab
    /// What VoiceOver calls the group.
    var label = "Sections"

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(tabs, id: \.id) { tab in
                Button(tab.title) { selection = tab.id }
                    .buttonStyle(KitTabStyle(isSelected: tab.id == selection))
                    .accessibilityAddTraits(tab.id == selection ? .isSelected : [])
            }
        }
        .onMoveCommand { direction in
            guard let index = tabs.firstIndex(where: { $0.id == selection }) else { return }
            switch direction {
            case .left: selection = tabs[max(index - 1, 0)].id
            case .right: selection = tabs[min(index + 1, tabs.count - 1)].id
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

struct KitTabStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TabBody(configuration: configuration, isSelected: isSelected)
    }

    private struct TabBody: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @Environment(\.forcedPartState) private var forced
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        private var state: PartState {
            forced ?? (!isEnabled ? .disabled : isSelected ? .selected : configuration.isPressed ? .pressed
                : hovering ? .hover : isFocused ? .focused : .rest)
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
            configuration.label
                .kitType(.status)
                .foregroundStyle(state == .rest || state == .disabled ? Ink.textSoft : Ink.text)
                .padding(.horizontal, Space.md)
                .frame(height: Metric.tabHeight)
                .background(shape.fill(state == .hover || state == .pressed ? Ink.wash : .clear))
                .overlay(alignment: .bottom) {
                    Capsule().fill(state == .selected ? Ink.accent : .clear)
                        .frame(height: Metric.tabUnderline)
                        .padding(.horizontal, Space.md)
                }
                .overlay {
                    if state == .focused {
                        shape.strokeBorder(Ink.accent, lineWidth: Metric.focusRing)
                    }
                }
                .opacity(state == .disabled ? 0.4 : 1)
                .animation(Motion.hover, value: state)
                .onHover { hovering = $0 && !Snapshot.isRunning }
                .contentShape(shape)
        }
    }
}

/// A titled group of settings rows in one card, with hairlines between rows.
struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: Space.sm) {
            if let title {
                Text(title).kitType(.section).foregroundStyle(Ink.accentText)
                    .padding(.leading, Space.lg)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            KitDivider().padding(.leading, Space.lg)
                        }
                        row
                    }
                }
            }
            .background(shape.fill(Ink.raised))
            .overlay(shape.strokeBorder(Ink.hairline, lineWidth: Metric.hairline))
        }
    }
}

/// One setting: what it is on the left, its control on the right.
struct SettingsRow<Control: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).kitType(.body).foregroundStyle(Ink.text)
                if let detail {
                    Text(detail).kitType(.meta).foregroundStyle(Ink.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.lg)
            control
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .frame(minHeight: Metric.rowHeight)
    }
}

/// A dot and a word: the state of something, never the dot alone.
struct StatusPill: View {
    enum Tone { case idle, good, warning }
    var text: String
    var tone: Tone = .idle

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(tone == .good ? Ink.accent : tone == .warning ? Ink.warning : Ink.textSoft)
                .frame(width: Metric.statusDot, height: Metric.statusDot)
            Text(text).kitType(.body).foregroundStyle(tone == .warning ? Ink.warning : Ink.text)
        }
        .accessibilityElement(children: .combine)
    }
}
