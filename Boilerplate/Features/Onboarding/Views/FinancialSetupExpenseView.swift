import SwiftUI

struct FinancialSetupExpenseView: View {
    let userType: OnboardingUserType
    let uid: String
    let onboarding: OnboardingService
    var onIncomeCompleted: () async -> Void
    var onExpenseCompleted: () async -> Void

    var body: some View {
        let (_, expense) = OnboardingFinancialConstants.categories(for: userType)
        FinancialCategoryFlowView(
            kind: .expense,
            categories: expense,
            uid: uid,
            onboarding: onboarding,
            onIncomeCompleted: onIncomeCompleted,
            onExpenseCompleted: onExpenseCompleted
        )
    }
}
