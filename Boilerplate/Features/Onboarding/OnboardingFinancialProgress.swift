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

    // MARK: - Local completion (Firestore `hasFinancialData` can lag after expense save)

    private static func localHasFinancialDataKey(uid: String) -> String {
        "onboarding_local_has_financial_data_\(uid)"
    }

    /// Persisted when the user finishes income + expense so routing does not depend on Firestore alone.
    static func markLocalHasFinancialDataComplete(uid: String) {
        UserDefaults.standard.set(true, forKey: localHasFinancialDataKey(uid: uid))
    }

    static func hasLocalHasFinancialDataComplete(uid: String) -> Bool {
        UserDefaults.standard.bool(forKey: localHasFinancialDataKey(uid: uid))
    }

    /// Merges `hasFinancialData: true` when this device has completed the financial setup flow.
    static func mergedProfileIfLocalFinancialComplete(_ profile: [String: Any], uid: String) -> [String: Any] {
        guard hasLocalHasFinancialDataComplete(uid: uid) else { return profile }
        var merged = profile
        merged["hasFinancialData"] = true
        return merged
    }
}
