import SwiftUI
import UIKit

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
    @Environment(\.colorScheme) private var colorScheme

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
            .foregroundStyle(primaryForegroundColor)
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
            return Color(uiColor: .tertiarySystemFill)
        }
        return AppTheme.Colors.budgeGreenPrimary
    }

    /// Enabled: brand dark green on green fill. Disabled (e.g. empty form): white in dark mode on gray fill.
    private var primaryForegroundColor: Color {
        if isEnabled {
            return AppTheme.Colors.budgeGreenDarkText
        }
        return colorScheme == .dark ? .white : AppTheme.Colors.budgeGreenDarkText
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
