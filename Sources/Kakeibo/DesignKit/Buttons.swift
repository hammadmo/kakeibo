import SwiftUI

/// Kit buttons. Real Buttons with a style, so keyboard, focus, and VoiceOver work.
///   Button("Top Up", action: topUp).buttonStyle(.kit())
///   Button("Discharge", action: discharge).buttonStyle(.kit(.secondary))
///   Button("Settings…", action: open).buttonStyle(.kit(.ghost))
struct KitButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .primary
    /// An active mode, for example Top Up while it runs.
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(configuration: configuration, kind: kind, isSelected: isSelected)
    }
}

extension ButtonStyle where Self == KitButtonStyle {
    static func kit(_ kind: KitButtonStyle.Kind = .primary, selected: Bool = false) -> KitButtonStyle {
        KitButtonStyle(kind: kind, isSelected: selected)
    }
}

private struct KitButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: KitButtonStyle.Kind
    let isSelected: Bool
    @Environment(\.forcedPartState) private var forced
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false

    private var state: PartState {
        forced ?? (!isEnabled ? .disabled : configuration.isPressed ? .pressed
            : hovering ? .hover : isFocused ? .focused : isSelected ? .selected : .rest)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
        configuration.label
            .kitType(.labelStrong)
            .lineLimit(1)
            .padding(.horizontal, kind == .ghost ? Space.sm : Space.md)
            .frame(maxWidth: kind == .ghost ? nil : .infinity)
            .frame(height: Metric.buttonHeight)
            .foregroundStyle(textColor)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: Metric.hairline))
            .overlay {
                if state == .focused {
                    shape.inset(by: -Metric.focusRing * 2)
                        .strokeBorder(Ink.accent, lineWidth: Metric.focusRing)
                }
            }
            .opacity(state == .disabled ? 0.4 : 1)
            .scaleEffect(state == .pressed ? 0.98 : 1)
            .animation(Motion.press, value: state)
            .onHover { hovering = $0 && !Snapshot.isRunning }
            .contentShape(shape)
    }

    private var active: Bool { state == .hover || state == .pressed || state == .selected }

    private var textColor: Color {
        switch kind {
        case .primary: Ink.onFill
        case .secondary: Ink.outlineText
        case .ghost: active ? Ink.text : Ink.textSoft
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: Ink.fill.opacity(state == .pressed ? 0.76 : active ? 0.88 : 1)
        case .secondary: active ? Ink.wash : .clear
        case .ghost: state == .hover || state == .pressed ? Ink.wash : .clear
        }
    }

    private var border: Color {
        switch kind {
        case .primary, .ghost: .clear
        case .secondary: state == .selected ? Ink.accent : Ink.outline
        }
    }
}
