import SwiftUI

struct WhyUseBudgeView: View {
    let onboarding: OnboardingService
    let uid: String
    let onFinished: () async -> Void

    @State private var isSaving = false

    private let options = [
        "Advice on Daily Finance",
        "Growing Wealth",
        "Track my Expenses",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                Text("How will you use Budge?")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)

                VStack(spacing: UIConstants.Spacing.md) {
                    ForEach(options, id: \.self) { name in
                        OnboardingOptionCard(title: name) {
                            Task { await select(name) }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .padding(UIConstants.Padding.section)
        }
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
    }

    private func select(_ name: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onboarding.updateUserProfile(uid: uid, fields: ["usingReason": name])
            await onFinished()
        } catch {
            try? await onboarding.updateUserProfile(uid: uid, fields: ["usingReason": name])
            await onFinished()
        }
    }
}
