import SwiftUI

struct BudgeSetupIntroView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer(minLength: UIConstants.Spacing.xxl)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)
                .accessibilityHidden(true)

            VStack(spacing: UIConstants.Spacing.md) {
                Text("Hello, I am Budge")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)
                Text("Your finance buddy — let’s personalize your experience.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, UIConstants.Padding.section)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, UIConstants.Padding.section)
                .padding(.bottom, UIConstants.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
    }
}
