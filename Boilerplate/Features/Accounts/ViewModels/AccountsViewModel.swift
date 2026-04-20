import Foundation

/// One row for My Accounts UI (web `fetchUserAccounts` parity: title-case name, active only in list).
struct AccountDisplayRow: Identifiable, Hashable {
    let id: String
    let displayName: String
    let type: String
    let currency: String
    let startingBalance: Double
    let currentBalance: Double
    let accountNumber: String
    let bankName: String
}

@Observable
final class AccountsViewModel {
    let uid: String
    private let onboarding: OnboardingService

    var rows: [AccountDisplayRow] = []
    var defaultAccountId: String?
    var isLoading = false
    var errorMessage: String?

    init(uid: String, onboarding: OnboardingService) {
        self.uid = uid
        self.onboarding = onboarding
    }

    /// Web `toTitleCase` in `fetchUserAccounts`.
    static func titleCaseName(_ raw: String) -> String {
        raw.split(separator: " ")
            .filter { !$0.isEmpty }
            .map { w in
                let s = String(w)
                guard let f = s.first else { return s }
                return String(f).uppercased() + s.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let profileTask = onboarding.fetchUserProfile(uid: uid)
            async let snapTask = onboarding.fetchFinanceSnapshot(
                year: OnboardingService.currentBudgetYear,
                monthKey: OnboardingService.currentBudgetMonthKey
            )
            let profile = try await profileTask
            let snap = try await snapTask

            defaultAccountId = profile["defaultAccountId"] as? String

            let active = snap.accounts.filter(\.isActive)
            rows = active.map { a in
                let rawName = a.name ?? ""
                let name = Self.titleCaseName(rawName.isEmpty ? "Account" : rawName)
                let cur = (a.currency ?? "USD").uppercased()
                let t = (a.type ?? "asset").lowercased()
                return AccountDisplayRow(
                    id: a.id,
                    displayName: name,
                    type: t,
                    currency: cur,
                    startingBalance: a.startingBalance ?? 0,
                    currentBalance: a.currentBalance ?? 0,
                    accountNumber: (a.accountNumber ?? "").isEmpty ? "—" : (a.accountNumber ?? ""),
                    bankName: (a.bankName ?? "").isEmpty ? "—" : (a.bankName ?? "")
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteAccounts(ids: [String]) async {
        for id in ids {
            do {
                try await onboarding.financeDeleteAccount(accountId: id)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        await load()
        NotificationCenter.default.post(name: .financeAccountsDidChange, object: nil)
    }

    @MainActor
    func createAccount(
        name: String,
        type: String,
        currency: String,
        startingBalance: Double?,
        accountNumber: String?,
        bankName: String?
    ) async throws {
        _ = try await onboarding.financeCreateAccount(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            currency: currency.uppercased(),
            startingBalance: startingBalance,
            accountNumber: accountNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        await load()
        NotificationCenter.default.post(name: .financeAccountsDidChange, object: nil)
    }

    @MainActor
    func updateAccount(
        accountId: String,
        name: String?,
        type: String?,
        currency: String?,
        startingBalance: Double?,
        accountNumber: String?,
        bankName: String?
    ) async throws {
        try await onboarding.financeUpdateAccount(
            accountId: accountId,
            name: name,
            type: type,
            currency: currency.map { $0.uppercased() },
            startingBalance: startingBalance,
            accountNumber: accountNumber,
            bankName: bankName
        )
        await load()
        NotificationCenter.default.post(name: .financeAccountsDidChange, object: nil)
    }

    @MainActor
    func transfer(from: String, to: String, amount: Double, note: String?) async throws {
        try await onboarding.financeTransfer(
            fromAccountId: from,
            toAccountId: to,
            amount: amount,
            note: note
        )
        await load()
        NotificationCenter.default.post(name: .financeAccountsDidChange, object: nil)
    }
}
