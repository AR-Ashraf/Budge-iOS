import SwiftUI

struct KnowFromPlatformView: View {
    let onboarding: OnboardingService
    let uid: String
    let onFinished: () async -> Void

    @State private var isSaving = false

    private let options = ["Google", "Friends/Family", "Social Media"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                Text("Where did you hear about Budge?")
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
            try await onboarding.updateUserProfile(uid: uid, fields: ["platform": name])
            await onFinished()
        } catch {
            // Still advance; write is best-effort
            try? await onboarding.updateUserProfile(uid: uid, fields: ["platform": name])
            await onFinished()
        }
    }
}
