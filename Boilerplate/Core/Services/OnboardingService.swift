import Foundation
import FirebaseFirestore

/// Firestore-backed onboarding (plaintext balances; matches React paths: `users/{uid}`, `financialTypes`, `budget`, `users/{uid}/accounts`).
@Observable
final class OnboardingService {
    private var db: Firestore { Firestore.firestore() }

    // MARK: - User profile snapshot

    func fetchUserProfile(uid: String) async throws -> [String: Any] {
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        return snap.data() ?? [:]
    }

    /// Merge-update user fields (plain numbers for balances).
    func updateUserProfile(uid: String, fields: [String: Any]) async throws {
        let ref = db.collection("users").document(uid)
        try await ref.setData(fields, merge: true)
    }

    /// Save starting balance + currency; mirrors `currentBalance` when missing.
    func saveManageBalance(uid: String, startingBalance: Double, currency: String) async throws {
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        let existing = snap.data() ?? [:]
        var patch: [String: Any] = [
            "startingBalance": startingBalance,
            "currency": currency,
        ]
        if existing["currentBalance"] == nil {
            patch["currentBalance"] = startingBalance
        }
        try await ref.setData(patch, merge: true)
        try await ensureDefaultMainAccount(uid: uid, currency: currency, startingBalance: startingBalance)
    }

    /// Ensure a Main Account exists (same shape as React `ensureDefaultMainAccount` / `createAccount`).
    func ensureDefaultMainAccount(uid: String, currency: String, startingBalance: Double) async throws {
        let userRef = db.collection("users").document(uid)
        let userSnap = try await userRef.getDocument()
        let ud = userSnap.data() ?? [:]
        if let existing = ud["defaultAccountId"] as? String, !existing.isEmpty { return }

        // Reuse active Main Account if present
        let accountsCol = userRef.collection("accounts")
        let q = try await accountsCol
            .whereField("isActive", isEqualTo: true)
            .whereField("name", isEqualTo: "Main Account")
            .limit(to: 1)
            .getDocuments()
        if let doc = q.documents.first {
            try await userRef.setData([
                "isMultiAccountEnabled": true,
                "defaultAccountId": doc.documentID,
            ], merge: true)
            return
        }

        let accountId = UUID().uuidString
        let accountRef = accountsCol.document(accountId)
        let now = Timestamp(date: Date())
        try await accountRef.setData([
            "id": accountId,
            "name": "Main Account",
            "type": "asset",
            "currency": currency,
            "startingBalance": startingBalance,
            "currentBalance": startingBalance,
            "isActive": true,
            "createdAt": now,
            "updatedAt": now,
        ])
        try await userRef.setData([
            "isMultiAccountEnabled": true,
            "defaultAccountId": accountId,
        ], merge: true)
    }

    /// Seed `financialTypes/{uid}/income|expense/{key}` — does **not** set `hasFinancialData`.
    func seedFinancialCategoryDocuments(uid: String, userType: OnboardingUserType) async throws {
        let (income, expense) = OnboardingFinancialConstants.categories(for: userType)
        let batch = db.batch()
        for c in income {
            let r = db.collection("financialTypes").document(uid).collection("income").document(c.key)
            batch.setData([
                "key": c.key,
                "name": c.name,
                "category": "income",
            ], forDocument: r, merge: true)
        }
        for c in expense {
            let r = db.collection("financialTypes").document(uid).collection("expense").document(c.key)
            batch.setData([
                "key": c.key,
                "name": c.name,
                "category": "expense",
            ], forDocument: r, merge: true)
        }
        try await batch.commit()
    }

    /// Budget path matches web: `budget/{uid}/{type}/{year}/{key}/aggregate` with `data.{monthKey}` = number (plaintext).
    func saveBudgetAggregates(uid: String, type: String, year: String, amountsByKey: [String: Double], monthKey: String) async throws {
        let batch = db.batch()
        for (key, amount) in amountsByKey {
            let ref = db.collection("budget").document(uid).collection(type).document(year).collection(key).document("aggregate")
            batch.setData([
                "key": key,
                "category": type,
                "data": [monthKey: amount],
            ], forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    static var currentBudgetMonthKey: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f.string(from: Date())
    }

    static var currentBudgetYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    func setHasFinancialData(uid: String, _ value: Bool) async throws {
        try await updateUserProfile(uid: uid, fields: ["hasFinancialData": value])
    }

    /// React parity: after `userType` selection, seed categories (if needed), seed 0 budgets, and mark `hasFinancialData=true`.
    func seedZeroBudgetsAndMarkFinancialData(uid: String, userType: OnboardingUserType) async throws {
        // Ensure financial types exist.
        let (incCount, expCount) = try await fetchFinancialCategoriesCount(uid: uid)
        if incCount == 0, expCount == 0 {
            try await seedFinancialCategoryDocuments(uid: uid, userType: userType)
        }

        let (income, expense) = OnboardingFinancialConstants.categories(for: userType)
        let year = Self.currentBudgetYear
        let monthKey = Self.currentBudgetMonthKey

        let incomeZero = Dictionary(uniqueKeysWithValues: income.map { ($0.key, 0.0) })
        let expenseZero = Dictionary(uniqueKeysWithValues: expense.map { ($0.key, 0.0) })

        // Seed 0 budgets for current month (merge=true) so docs exist.
        try await saveBudgetAggregates(uid: uid, type: "income", year: year, amountsByKey: incomeZero, monthKey: monthKey)
        try await saveBudgetAggregates(uid: uid, type: "expense", year: year, amountsByKey: expenseZero, monthKey: monthKey)

        // Mark complete.
        try await setHasFinancialData(uid: uid, true)
    }

    /// Count financial type docs (income + expense).
    func fetchFinancialCategoriesCount(uid: String) async throws -> (income: Int, expense: Int) {
        let inc = try await db.collection("financialTypes").document(uid).collection("income").getDocuments()
        let exp = try await db.collection("financialTypes").document(uid).collection("expense").getDocuments()
        return (inc.documents.count, exp.documents.count)
    }

    // MARK: - Routing helpers

    /// Next major step from Firestore profile (no E2EE gates).
    func nextMajorStep(from profile: [String: Any]) -> OnboardingMajorStep {
        if !hasStartingBalance(profile) { return .manageBalance }
        let userType = profile["userType"] as? String
        if userType == nil || userType?.isEmpty == true { return .budgeIntro }
        if profile["platform"] == nil || (profile["platform"] as? String)?.isEmpty == true { return .knowPlatform }
        let reason = profile["usingReason"] as? String ?? profile["whyUseBudge"] as? String
        if reason == nil || reason?.isEmpty == true { return .whyUseBudge }
        if let hasFinancial = profile["hasFinancialData"] as? Bool, hasFinancial {
            return .chat
        }
        return .financialSetup
    }

    private func hasStartingBalance(_ profile: [String: Any]) -> Bool {
        if let n = profile["startingBalance"] as? Double { return n >= 0 }
        if let n = profile["startingBalance"] as? Int { return n >= 0 }
        if let n = profile["startingBalance"] as? NSNumber { return n.doubleValue >= 0 }
        return false
    }
}

enum OnboardingMajorStep: Hashable {
    case manageBalance
    case budgeIntro
    case knowPlatform
    case whyUseBudge
    case financialSetup
    case chat
}
