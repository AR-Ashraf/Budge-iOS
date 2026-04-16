import SwiftUI

/// Selectable card matching Chakra starter `Platform` / `userType` cards (mobile spacing).
struct OnboardingOptionCard: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, UIConstants.Spacing.xl)
                .padding(.vertical, UIConstants.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.extraLarge)
                        .fill(AppTheme.Colors.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.extraLarge)
                        .stroke(AppTheme.Colors.separator, lineWidth: UIConstants.Border.standard)
                )
        }
        .buttonStyle(.plain)
    }
}
