import Foundation
import SwiftUI

/// Single budget matrix cell pending save (blank field → 0 on save).
struct PendingBudgetCellEdit: Hashable, Sendable {
    let type: String
    let key: String
    let monthKey: String
    let amount: Double
}

enum ChartTab: String, CaseIterable, Identifiable {
    case budget
    case transaction
    case yearlyReport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .budget: "Budget"
        case .transaction: "Transaction"
        case .yearlyReport: "Yearly Report"
        }
    }
}

@Observable
final class ChartViewModel {
    let uid: String
    private let onboarding: OnboardingService

    var selectedTab: ChartTab = .budget
    var year: Int = Calendar.current.component(.year, from: Date())

    var isLoading = false
    /// True while saving inline edits from the nav bar (budget cells / transaction notes).
    var isSavingInlineEdit = false
    /// True while snapshot balances / account list are loading for the summary header.
    var isAccountSummaryLoading = false
    var errorMessage: String?

    var incomeRows: [[String: Any]] = []
    var expenseRows: [[String: Any]] = []
    var yearlyIncome: [[String: Any]] = []
    var yearlyExpense: [[String: Any]] = []

    var transactions: [[String: Any]] = []
    /// `afterPage[i]` = cursor to fetch page `i + 2` (i.e. after page `i + 1`).
    private var txCursorsAfterPage: [OnboardingService.TransactionCursor?] = []
    var txCurrentPage: Int = 1
    var txHasMore = false
    var txLoading = false

    var accounts: [OnboardingService.FinanceAccountSnapshot] = []
    var userCurrency: String = "USD"
    var defaultAccountId: String?
    var isMultiAccountEnabled = false
    var startingBalance: Double = 0
    var currentBalance: Double = 0

    var incomeTypes: [[String: Any]] = []
    var expenseTypes: [[String: Any]] = []

    var accountsExpanded = false

    init(uid: String, onboarding: OnboardingService) {
        self.uid = uid
        self.onboarding = onboarding
    }

    private var yearString: String { String(year) }

    /// First paint of the chart sheet: profile/snapshot, category labels, and tab content all fetch in parallel.
    @MainActor
    func loadInitialChartData() async {
        async let profile = loadProfileAndAccounts()
        async let types = loadFinancialTypes()
        async let tab = loadTabData()
        await profile
        await types
        await tab
    }

    @MainActor
    func loadProfileAndAccounts() async {
        isAccountSummaryLoading = true
        defer { isAccountSummaryLoading = false }
        do {
            // Header beside "Accounts": `users/{uid}.currency` + user aggregate current balance (KMS plaintext via snapshot;
            // matches `users/{uid}.currentBalance` on the server — same pattern as `ChatViewModel.refreshFinanceHeader`).
            async let profileTask = onboarding.fetchUserProfile(uid: uid)
            async let snapTask = onboarding.fetchFinanceSnapshot(year: yearString, monthKey: OnboardingService.currentBudgetMonthKey)
            let profile = try await profileTask
            let snap = try await snapTask

            if let c = profile["currency"] as? String, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                userCurrency = c.uppercased()
            } else {
                userCurrency = "USD"
            }
            defaultAccountId = profile["defaultAccountId"] as? String
            isMultiAccountEnabled = (profile["isMultiAccountEnabled"] as? Bool) ?? false
            startingBalance = Self.parseDouble(profile["startingBalance"]) ?? 0
            currentBalance = Self.parseDouble(profile["currentBalance"]) ?? 0

            accounts = snap.accounts
            if let sb = snap.startingBalance { startingBalance = sb }
            if let cb = snap.currentBalance { currentBalance = cb }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadFinancialTypes() async {
        do {
            let t = try await onboarding.fetchFinancialTypeRows(uid: uid)
            incomeTypes = t.income
            expenseTypes = t.expense
        } catch {}
    }

    @MainActor
    func loadTabData() async {
        isLoading = true
        defer { isLoading = false }
        switch selectedTab {
        case .budget:
            await loadBudgetData()
        case .transaction:
            await loadTransactions(reset: true)
        case .yearlyReport:
            await loadYearlyData()
        }
    }

    @MainActor
    func loadBudgetData() async {
        do {
            let p = try await onboarding.fetchBudgetYearDecrypted(year: yearString)
            incomeRows = p.income
            expenseRows = p.expense
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadYearlyData() async {
        do {
            let p = try await onboarding.fetchYearlyReportDecrypted(year: yearString)
            yearlyIncome = p.income
            yearlyExpense = p.expense
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadTransactions(reset: Bool) async {
        if reset {
            txCursorsAfterPage = []
            txCurrentPage = 1
        }
        await fetchTxPage(txCurrentPage)
    }

    @MainActor
    private func fetchTxPage(_ pageNum: Int) async {
        txLoading = true
        defer { txLoading = false }
        do {
            let cursor: OnboardingService.TransactionCursor? =
                pageNum <= 1 ? nil : txCursorsAfterPage[safe: pageNum - 2] ?? nil
            let page = try await onboarding.fetchTransactionsPage(limit: 25, cursor: cursor)
            transactions = page.transactions.map { Self.mapTransactionRow($0) }
            txHasMore = page.hasMore
            if let next = page.nextCursor {
                let idx = pageNum - 1
                while txCursorsAfterPage.count <= idx {
                    txCursorsAfterPage.append(nil)
                }
                txCursorsAfterPage[idx] = next
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func txNextPage() async {
        guard txHasMore else { return }
        txCurrentPage += 1
        await fetchTxPage(txCurrentPage)
    }

    @MainActor
    func txPrevPage() async {
        guard txCurrentPage > 1 else { return }
        txCurrentPage -= 1
        await fetchTxPage(txCurrentPage)
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if value == nil { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func mapTransactionRow(_ t: [String: Any]) -> [String: Any] {
        let amountPlain = (t["amountPlain"] as? NSNumber)?.doubleValue ?? (t["amountPlain"] as? Double) ?? 0
        let absAmt = abs(amountPlain)
        let cat = (t["category"] as? String)?.lowercased() == "income" ? "income" : "expense"
        let dep = cat == "income" ? absAmt : 0.0
        let pay = cat == "expense" ? absAmt : 0.0
        let run = (t["runningBalance"] as? NSNumber)?.doubleValue ?? (t["runningBalance"] as? Double)
        let posting = t["postingTime"] as? String ?? ""
        let dateDisplay = (t["dateDisplay"] as? String) ?? ""
        return [
            "id": t["id"] as? String ?? "",
            "accountId": t["accountId"] as? String ?? "",
            "key": t["key"] as? String ?? "",
            "category": cat,
            "note": t["note"] as? String ?? "",
            "postingTime": posting,
            "date": dateDisplay,
            "deposit": dep,
            "payment": pay,
            "balance": run ?? 0,
            "accountBalance": run ?? 0,
        ]
    }

    func categoryDisplayName(key: String) -> String {
        let all = incomeTypes + expenseTypes
        if let row = all.first(where: { ($0["key"] as? String)?.lowercased() == key.lowercased() }) {
            return (row["name"] as? String) ?? key
        }
        return key
    }

    @MainActor
    func saveBudgetCell(type: String, key: String, monthKey: String, amount: Double) async {
        do {
            try await onboarding.financeSetBudgetAggregate(
                type: type,
                year: yearString,
                key: key,
                monthKey: monthKey,
                amount: amount
            )
            await loadBudgetData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persists only the given cells (one callable each), then a single reload.
    @MainActor
    func saveBudgetCellsBatch(_ edits: [PendingBudgetCellEdit]) async -> Bool {
        guard !edits.isEmpty else { return true }
        isSavingInlineEdit = true
        defer { isSavingInlineEdit = false }
        do {
            for e in edits {
                try await onboarding.financeSetBudgetAggregate(
                    type: e.type,
                    year: yearString,
                    key: e.key,
                    monthKey: e.monthKey,
                    amount: e.amount
                )
            }
            await loadBudgetData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Updates only the listed transaction notes (one patch each), then one list reload.
    @MainActor
    func saveTransactionNotesBatch(_ pairs: [(id: String, note: String)]) async -> Bool {
        guard !pairs.isEmpty else { return true }
        isSavingInlineEdit = true
        defer { isSavingInlineEdit = false }
        do {
            for p in pairs {
                try await onboarding.financeUpdateTransaction(txId: p.id, patch: ["note": p.note])
            }
            await loadTransactions(reset: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func createCategory(type: String, name: String, amount: Double?) async {
        do {
            _ = try await onboarding.financeCreateBudgetCategory(
                type: type,
                name: name,
                amountForCurrentMonth: amount,
                year: yearString
            )
            await loadFinancialTypes()
            await loadBudgetData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Display name + all month cells in one pass (single reload at end).
    @MainActor
    func applyBudgetRowEdits(type: String, key: String, displayName: String, amountsByMonth: [String: Double]) async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await onboarding.updateFinancialCategoryDisplayName(uid: uid, type: type, key: key, name: trimmed)
            for (monthKey, amount) in amountsByMonth {
                try await onboarding.financeSetBudgetAggregate(
                    type: type,
                    year: yearString,
                    key: key,
                    monthKey: monthKey,
                    amount: amount
                )
            }
            await loadFinancialTypes()
            await loadBudgetData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Applies a full edit in one callable round-trip (amount is positive magnitude).
    @MainActor
    func updateTransactionEdits(
        txId: String,
        category: String,
        key: String,
        amount: Double,
        note: String,
        postingTime: String
    ) async {
        do {
            try await onboarding.financeUpdateTransaction(txId: txId, patch: [
                "category": category,
                "key": key.lowercased(),
                "amount": amount,
                "note": note,
                "postingTime": postingTime,
            ])
            await loadTransactions(reset: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteCategories(rows: [[String: Any]]) async {
        var uniq: [String: (String, String)] = [:]
        for r in rows {
            guard let k = r["key"] as? String,
                  let c = r["category"] as? String
            else { continue }
            uniq["\(c):\(k)"] = (c.lowercased(), k.lowercased())
        }
        for (_, pair) in uniq {
            do {
                try await onboarding.financeDeleteBudgetCategory(type: pair.0, key: pair.1)
            } catch {}
        }
        await loadFinancialTypes()
        await loadBudgetData()
    }

    @MainActor
    func deleteTransactions(ids: [String]) async {
        for id in ids {
            do {
                try await onboarding.financeDeleteTransaction(txId: id)
            } catch {}
        }
        await loadTransactions(reset: true)
    }

    @MainActor
    func createTransaction(
        accountId: String,
        category: String,
        key: String,
        amount: Double,
        note: String?,
        postingTime: String
    ) async throws {
        _ = try await onboarding.financeCreateTransaction(
            accountId: accountId,
            category: category,
            key: key,
            amount: amount,
            note: note,
            postingTime: postingTime
        )
    }

    @MainActor
    func updateTransactionField(txId: String, field: String, value: Any) async {
        var patch: [String: Any] = [:]
        switch field {
        case "amount":
            if let d = value as? Double {
                patch["amount"] = d
            }
        case "key":
            patch["key"] = value
        case "note":
            patch["note"] = value
        case "category":
            patch["category"] = value
        case "postingTime", "date":
            patch["postingTime"] = value
        default:
            break
        }
        guard !patch.isEmpty else { return }
        do {
            try await onboarding.financeUpdateTransaction(txId: txId, patch: patch)
            await loadTransactions(reset: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
