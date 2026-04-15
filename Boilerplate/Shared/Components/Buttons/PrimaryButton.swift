import SwiftUI

/// Primary action button with optional loading state and icon
struct PrimaryButton: View {
    // MARK: - Properties

    let title: String
    let action: () -> Void

    var icon: String?
    var isLoading: Bool = false
    var isFullWidth: Bool = true

    // MARK: - Environment

    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Body

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            HapticService.shared.buttonTap()
            action()
        }) {
            HStack(spacing: UIConstants.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppTheme.Colors.budgeGreenDarkText)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(AppTheme.Typography.buttonLabel)
                }
            }
            .foregroundStyle(AppTheme.Colors.budgeGreenDarkText)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: UIConstants.ButtonSize.medium)
            .padding(.horizontal, isFullWidth ? 0 : UIConstants.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.pill)
                    .fill(backgroundColor)
            )
        }
        .disabled(isLoading)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if !isEnabled {
            return .gray
        }
        return AppTheme.Colors.budgeGreenPrimary
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue", action: {
        })

        PrimaryButton(title: "Submit", action: {
        }, icon: "paperplane.fill")

        PrimaryButton(title: "Loading", action: {
        }, isLoading: true)

        PrimaryButton(title: "Disabled", action: {
        })
        .disabled(true)

        PrimaryButton(title: "Compact", action: {
        }, isFullWidth: false)
    }
    .padding()
}
