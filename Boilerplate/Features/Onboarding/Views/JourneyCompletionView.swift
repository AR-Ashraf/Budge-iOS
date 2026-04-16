import SwiftUI

struct JourneyCompletionView: View {
    let onEnterChat: () -> Void

    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)

            VStack(spacing: UIConstants.Spacing.sm) {
                Text("You’re all set!")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)
                Text("Jump into chat to plan your finances with Budge.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, UIConstants.Padding.section)

            Spacer()

            PrimaryButton(title: "Go to chat", action: onEnterChat)
                .padding(.horizontal, UIConstants.Padding.section)
                .padding(.bottom, UIConstants.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
    }
}
