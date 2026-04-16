import Foundation

/// Persists financial-setup sub-step across app restarts (parity with web resuming mid-flow).
enum OnboardingFinancialSubStep: String {
    case income
    case postIncomeCelebration
    case expense
}

enum OnboardingFinancialProgress {
    private static func storageKey(uid: String) -> String {
        "onboarding_financial_substep_\(uid)"
    }

    static func load(uid: String) -> OnboardingFinancialSubStep {
        guard let raw = UserDefaults.standard.string(forKey: storageKey(uid: uid)),
              let step = OnboardingFinancialSubStep(rawValue: raw) else {
            return .income
        }
        return step
    }

    static func save(_ step: OnboardingFinancialSubStep, uid: String) {
        UserDefaults.standard.set(step.rawValue, forKey: storageKey(uid: uid))
    }

    static func clear(uid: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(uid: uid))
    }
}
