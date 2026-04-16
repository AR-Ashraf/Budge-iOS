import SwiftUI

/// Mirrors `initialization-completion` → short celebration before financial setup.
struct InitializationCompletionView: View {
    let onContinue: () -> Void

    @State private var didFire = false

    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer()

            Image(systemName: "hands.clap.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)

            VStack(spacing: UIConstants.Spacing.sm) {
                Text("Congratulations!!")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)
                Text("You’ve done a great job.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, UIConstants.Padding.section)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
        .onAppear {
            guard !didFire else { return }
            didFire = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onContinue()
            }
        }
    }
}
