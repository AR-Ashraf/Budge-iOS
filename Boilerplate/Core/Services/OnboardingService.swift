import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Serializes Cloud Functions HTTPS callable traffic so `GTMSessionFetcher` never runs overlapping requests
/// (e.g. `finance_getSnapshot` starting before `finance_setBalances` completes). Shared across all
/// `OnboardingService` instances (there should be only one).
private actor FinanceHTTPSerializer {
    func run<T>(_ operation: () async throws -> T) async rethrows -> T {
        try await operation()
    }
}

/// Firestore-backed onboarding (plaintext balances; matches React paths: `users/{uid}`, `financialTypes`, `budget`, `users/{uid}/accounts`).
@Observable
final class OnboardingService {
    private static let sharedFinanceGate = FinanceHTTPSerializer()

    private var db: Firestore { Firestore.firestore() }
    private var functions: Functions { Functions.functions(region: "us-central1") }
    private var financeCalls: FinanceHTTPSerializer { Self.sharedFinanceGate }

    // MARK: - User profile snapshot

    func fetchUserProfile(uid: String) async throws -> [String: Any] {
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        return snap.data() ?? [:]
    }

    /// Merge-update user fields (plain non-finance fields only).
    func updateUserProfile(uid: String, fields: [String: Any]) async throws {
        let ref = db.collection("users").document(uid)
        try await ref.setData(fields, merge: true)
    }

    /// Save currency in Firestore and write finance balances via Functions so Firestore stores ciphertext only.
    /// The entire operation holds the finance gate so no other callable (e.g. `finance_getSnapshot`) can run
    /// until `finance_setBalances` / `finance_setAccountBalance` finish — avoids GTMSessionFetcher overlap and
    /// misleading errors on the read path.
    func saveManageBalance(uid: String, startingBalance: Double, currency: String) async throws {
        let fns = functions
        try await financeCalls.run {
            let ref = self.db.collection("users").document(uid)
            try await ref.setData(["currency": currency], merge: true)
            let accountId = try await self.ensureDefaultMainAccount(uid: uid, currency: currency)
            // Plain Doubles + NSNumber: Firebase callable JSON encoding varies by SDK version.
            let payload: [String: Any] = [
                "startingBalance": NSNumber(value: startingBalance),
                "currentBalance": NSNumber(value: startingBalance),
            ]
            let setBalances = fns.httpsCallable("finance_setBalances")
            _ = try await setBalances.call(payload)
            let setAccount = fns.httpsCallable("finance_setAccountBalance")
            _ = try await setAccount.call([
                "accountId": accountId,
                "startingBalance": NSNumber(value: startingBalance),
                "currentBalance": NSNumber(value: startingBalance),
            ] as [String: Any])
        }
    }

    /// Ensure a Main Account exists (same shape as React `ensureDefaultMainAccount` / `createAccount`).
    @discardableResult
    func ensureDefaultMainAccount(uid: String, currency: String) async throws -> String {
        let userRef = db.collection("users").document(uid)
        let userSnap = try await userRef.getDocument()
        let ud = userSnap.data() ?? [:]
        if let existing = ud["defaultAccountId"] as? String, !existing.isEmpty { return existing }

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
            return doc.documentID
        }

        let accountId = UUID().uuidString
        let accountRef = accountsCol.document(accountId)
        let now = Timestamp(date: Date())
        try await accountRef.setData([
            "id": accountId,
            "name": "Main Account",
            "type": "asset",
            "currency": currency,
            "isActive": true,
            "createdAt": now,
            "updatedAt": now,
        ])
        try await userRef.setData([
            "isMultiAccountEnabled": true,
            "defaultAccountId": accountId,
        ], merge: true)
        return accountId
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

    /// Budget path matches web: `budget/{uid}/{type}/{year}/{key}/aggregate`, but values are written via Functions as ciphertext.
    func saveBudgetAggregates(uid: String, type: String, year: String, amountsByKey: [String: Double], monthKey: String) async throws {
        try await financeCalls.run { [functions] in
            for (key, amount) in amountsByKey {
                let callable = functions.httpsCallable("finance_setBudgetAggregate")
                _ = try await callable.call([
                    "type": type,
                    "year": year,
                    "key": key,
                    "monthKey": monthKey,
                    "amount": amount,
                ])
            }
        }
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
        try await financeCalls.run { [functions] in
            let callable = functions.httpsCallable("finance_seedZeroBudgets")
            _ = try await callable.call([
                "userType": userType.rawValue,
                "year": Self.currentBudgetYear,
                "monthKey": Self.currentBudgetMonthKey,
            ])
        }
    }

    /// Count financial type docs (income + expense).
    func fetchFinancialCategoriesCount(uid: String) async throws -> (income: Int, expense: Int) {
        let inc = try await db.collection("financialTypes").document(uid).collection("income").getDocuments()
        let exp = try await db.collection("financialTypes").document(uid).collection("expense").getDocuments()
        return (inc.documents.count, exp.documents.count)
    }

    struct FinanceSnapshot {
        let startingBalance: Double?
        let currentBalance: Double?
        let accounts: [FinanceAccountSnapshot]
        let budgetsByType: [String: [String: Double]]
        let year: String
        let monthKey: String
    }

    struct FinanceAccountSnapshot: Identifiable {
        let id: String
        let name: String?
        let startingBalance: Double?
        let currentBalance: Double?
    }

    /// Server-decrypted finance read path. Firestore stores ciphertext; UI receives plaintext via Functions.
    func fetchFinanceSnapshot(year: String = currentBudgetYear, monthKey: String = currentBudgetMonthKey) async throws -> FinanceSnapshot {
        try await financeCalls.run { [functions] in
            let callable = functions.httpsCallable("finance_getSnapshot")
            let result = try await callable.call([
                "year": year,
                "monthKey": monthKey,
            ])

            guard let payload = result.data as? [String: Any] else {
                throw NSError(domain: "OnboardingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid finance snapshot response"])
            }

            let balances = payload["balances"] as? [String: Any]
            let startingBalance = Self.doubleFromJSONValue(balances?["startingBalance"])
            let currentBalance = Self.doubleFromJSONValue(balances?["currentBalance"])

            let accounts = (payload["accounts"] as? [[String: Any]] ?? []).map { item in
                FinanceAccountSnapshot(
                    id: item["id"] as? String ?? UUID().uuidString,
                    name: item["name"] as? String,
                    startingBalance: Self.doubleFromJSONValue(item["startingBalance"]),
                    currentBalance: Self.doubleFromJSONValue(item["currentBalance"])
                )
            }

            var budgetsByType: [String: [String: Double]] = [:]
            if let rawBudgets = payload["budgetsByType"] as? [String: [String: Any]] {
                for (type, items) in rawBudgets {
                    var typed: [String: Double] = [:]
                    for (key, value) in items {
                        if let amount = value as? Double {
                            typed[key] = amount
                        } else if let amount = value as? NSNumber {
                            typed[key] = amount.doubleValue
                        }
                    }
                    budgetsByType[type] = typed
                }
            }

            return FinanceSnapshot(
                startingBalance: startingBalance,
                currentBalance: currentBalance,
                accounts: accounts,
                budgetsByType: budgetsByType,
                year: payload["year"] as? String ?? year,
                monthKey: payload["monthKey"] as? String ?? monthKey
            )
        }
    }

    /// Firebase callable payloads often use `NSNumber` for JSON numbers.
    private static func doubleFromJSONValue(_ value: Any?) -> Double? {
        if value == nil { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    func migrateCurrentUserFinanceData() async throws {
        try await financeCalls.run { [functions] in
            let callable = functions.httpsCallable("finance_migrateCurrentUserData")
            _ = try await callable.call()
        }
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
        if let s = profile["startingBalance"] as? String { return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
