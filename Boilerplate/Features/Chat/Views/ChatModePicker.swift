import SwiftUI

/// Compact dropdown letting the user pick how the next message is handled:
/// Ask (quick Q&A), Agent (take actions), or Plan (long-term planner with charts).
///
/// Visually a pill chip with mode icon + name + chevron, color-tinted per mode
/// using ``BudgeChatPalette/modeChipBackground(_:)``. Mirrors Cursor's chat mode
/// selector placement at the leading edge of the composer toolbar row.
struct ChatModePicker: View {
    @Binding var mode: ChatMode

    @Environment(\.colorScheme) private var colorScheme

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    var body: some View {
        Menu {
            ForEach(ChatMode.allCases) { option in
                Button {
                    if mode != option {
                        mode = option
                    }
                } label: {
                    if option == mode {
                        Label {
                            VStack(alignment: .leading) {
                                Text(option.displayName)
                                Text(option.menuSubtitle)
                                    .font(.caption2)
                            }
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Label {
                            VStack(alignment: .leading) {
                                Text(option.displayName)
                                Text(option.menuSubtitle)
                                    .font(.caption2)
                            }
                        } icon: {
                            Image(systemName: option.sfSymbol)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.sfSymbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.75)
            }
            .foregroundStyle(palette.modeChipForeground(mode))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.modeChipBackground(mode))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(palette.modeChipForeground(mode).opacity(0.12), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chat mode")
        .accessibilityValue(mode.displayName)
        .animation(.easeInOut(duration: 0.15), value: mode)
    }
}

#Preview {
    @Previewable @State var m: ChatMode = .ask
    return VStack(spacing: 12) {
        ChatModePicker(mode: $m)
        ChatModePicker(mode: .constant(.agent))
        ChatModePicker(mode: .constant(.plan))
    }
    .padding()
}
