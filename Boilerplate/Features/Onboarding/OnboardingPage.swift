import Foundation

/// Mirrors React onboarding route paths for logging + parity checks.
enum OnboardingPage: String, Hashable {
    case manageBalance = "/manage-balance"
    case budgeSetupIntro = "/budge-setup"
    case budgeSetupUserType = "/budge-setup/userType"
    case budgeSetupKnowFromPlatform = "/budge-setup/knowFromPlatform"
    case budgeSetupWhyUseBudge = "/budge-setup/whyUseBudge"
    case initializationCompletion = "/initialization-completion"
    case financialSetupIncome = "/financial-setup/income"
    case financialSetupCompletion = "/financial-setup/completion"
    case financialSetupExpense = "/financial-setup/expense"
    case journeyCompletion = "/journey-completion"
    case chat = "/chat"
}

