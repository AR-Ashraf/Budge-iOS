import SwiftUI

struct FinancialSetupIncomeView: View {
    let userType: OnboardingUserType
    let uid: String
    let onboarding: OnboardingService
    var onIncomeCompleted: () async -> Void
    var onExpenseCompleted: () async -> Void

    var body: some View {
        let (income, _) = OnboardingFinancialConstants.categories(for: userType)
        FinancialCategoryFlowView(
            kind: .income,
            categories: income,
            uid: uid,
            onboarding: onboarding,
            onIncomeCompleted: onIncomeCompleted,
            onExpenseCompleted: onExpenseCompleted
        )
    }
}
