import SwiftUI

/// Interstitial between income and expense (`/financial-setup/completion`).
struct FinancialSetupCompletionView: View {
    let onContinue: () -> Void

    @State private var didFire = false

    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)

            VStack(spacing: UIConstants.Spacing.sm) {
                Text("Nice work!")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)
                Text("Let’s capture your expenses next.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
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
