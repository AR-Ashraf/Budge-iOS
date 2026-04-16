import SwiftUI

struct UserTypeView: View {
    let onboarding: OnboardingService
    let uid: String
    let onFinished: () async -> Void

    @State private var isSaving = false

    private let choices: [OnboardingUserType] = [.jobHolder, .entrepreneur, .student]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                Text("Which best describes you?")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)

                VStack(spacing: UIConstants.Spacing.md) {
                    ForEach(choices) { choice in
                        OnboardingOptionCard(title: choice.rawValue) {
                            Task { await select(choice) }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .padding(UIConstants.Padding.section)
        }
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
    }

    private func select(_ userType: OnboardingUserType) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onboarding.updateUserProfile(uid: uid, fields: ["userType": userType.rawValue])
            let (inc, exp) = try await onboarding.fetchFinancialCategoriesCount(uid: uid)
            if inc == 0, exp == 0 {
                try await onboarding.seedFinancialCategoryDocuments(uid: uid, userType: userType)
            }
        } catch {
            // Best-effort: still try to persist userType so routing can proceed.
            try? await onboarding.updateUserProfile(uid: uid, fields: ["userType": userType.rawValue])
            try? await onboarding.seedFinancialCategoryDocuments(uid: uid, userType: userType)
        }
        await onFinished()
    }
}
