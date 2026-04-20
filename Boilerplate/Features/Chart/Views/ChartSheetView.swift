import Combine
import SwiftUI
import UIKit

struct ChartSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: ChartViewModel
    /// Tapped an account row in the expanded list — parent may dismiss and push `Accounts`.
    var onAccountRowTap: ((String) -> Void)? = nil

    @State private var showCreateBudget = false
    @State private var isSavingNewCategory = false
    @State private var showCreateTx = false
    @State private var showDeleteConfirm = false
    /// After delete confirmation: selection bar is dismissed first, then this shows until delete completes.
    @State private var isDeletingSelection = false
    @State private var selectedBudgetRows: Set<String> = []
    @State private var selectedTxIds: Set<String> = []
    @State private var sharePayload: SharePayload?
    @State private var newCategoryName = ""
    @State private var newCategoryType: String = "income"
    @State private var newTxAmount: String = ""
    @State private var newTxKey = ""
    @State private var newTxAccountId = ""

    @State private var activeEditSheet: ChartEditSheet?
    @State private var showEditSingleSelectionAlert = false

    /// `rowCategory:key` for matrix tables (budget + yearly).
    @State private var highlightedBudgetRowId: String?
    @State private var highlightedTransactionId: String?

    /// Draft budget cell edits (toolbar Save); key matches `BudgetMatrixTable` / `PendingBudgetCellEdit`.
    @State private var pendingBudgetEdits: [String: PendingBudgetCellEdit] = [:]
    /// Draft transaction note by tx id when different from server row.
    @State private var pendingNoteEdits: [String: String] = [:]
    @State private var isKeyboardVisible = false
    /// Prevents double-taps between keyboard dismiss and `model.isSavingInlineEdit` starting.
    @State private var isInlineSaveInProgress = false

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    private var showInlineSavingSpinner: Bool {
        model.isSavingInlineEdit && (model.selectedTab == .budget || model.selectedTab == .transaction)
    }

    private var hasInlineDirtyEdits: Bool {
        switch model.selectedTab {
        case .budget: !pendingBudgetEdits.isEmpty
        case .transaction: !pendingNoteEdits.isEmpty
        case .yearlyReport: false
        }
    }

    private var showInlineEditToolbar: Bool {
        isKeyboardVisible && (model.selectedTab == .budget || model.selectedTab == .transaction)
    }

    private enum ChartEditSheet: Identifiable {
        case budget(type: String, row: [String: Any])
        case transaction(row: [String: Any])

        var id: String {
            switch self {
            case .budget(let type, let row):
                return "b-\(type)-\((row["key"] as? String) ?? "")"
            case .transaction(let row):
                return "t-\((row["id"] as? String) ?? "")"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isMultiAccountEnabled {
                        accountSummaryCard
                    }

                    chartTabBar

                    HStack {
                        if model.selectedTab != .transaction {
                            yearPicker
                        }
                        Spacer()
                        chartActionsMenu
                    }

                    if model.isLoading {
                        ProgressView()
                            .tint(palette.brandGreenPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    Group {
                        switch model.selectedTab {
                        case .budget:
                            budgetContent
                        case .transaction:
                            transactionContent
                        case .yearlyReport:
                            yearlyContent
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, (hasSelection || isDeletingSelection) ? 76 : 0)
            }
            .background(palette.screenBackground)
            .overlay(alignment: .bottom) {
                if isDeletingSelection {
                    deletingSelectionBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                } else if hasSelection {
                    selectionActionsBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
            .navigationTitle("Balance Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if showInlineSavingSpinner {
                        ProgressView()
                    } else if showInlineEditToolbar {
                        if hasInlineDirtyEdits {
                            Button("Save") {
                                Task { await saveInlineEdits() }
                            }
                            .disabled(isInlineSaveInProgress)
                        } else {
                            Button("Done") {
                                dismissKeyboard()
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .financeAccountsDidChange)) { _ in
                Task { await model.loadProfileAndAccounts() }
            }
            .task {
                await model.loadInitialChartData()
            }
            .onChange(of: model.selectedTab) { _, _ in
                selectedBudgetRows.removeAll()
                selectedTxIds.removeAll()
                highlightedBudgetRowId = nil
                highlightedTransactionId = nil
                pendingBudgetEdits.removeAll()
                pendingNoteEdits.removeAll()
                Task { await model.loadTabData() }
            }
            .onChange(of: model.year) { _, _ in
                highlightedBudgetRowId = nil
                highlightedTransactionId = nil
                pendingBudgetEdits.removeAll()
                pendingNoteEdits.removeAll()
                Task { await model.loadTabData() }
            }
            .sheet(isPresented: $showCreateBudget) {
                NavigationStack {
                    Form {
                        Picker("Type", selection: $newCategoryType) {
                            Text("Income").tag("income")
                            Text("Expense").tag("expense")
                        }
                        TextField("Category name", text: $newCategoryName)
                    }
                    .navigationTitle("New category")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateBudget = false }
                                .disabled(isSavingNewCategory)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if isSavingNewCategory {
                                ProgressView()
                                    .tint(palette.brandGreenPrimary)
                            } else {
                                Button("Save") {
                                    Task { await saveNewCategory() }
                                }
                                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateTx) {
                NavigationStack {
                    Form {
                        Picker("Account", selection: $newTxAccountId) {
                            ForEach(model.accounts, id: \.id) { a in
                                Text(a.name ?? a.id).tag(a.id)
                            }
                        }
                        TextField("Amount", text: $newTxAmount)
                            .keyboardType(.decimalPad)
                        TextField("Category key", text: $newTxKey)
                        Picker("Type", selection: $newCategoryType) {
                            Text("Income").tag("income")
                            Text("Expense").tag("expense")
                        }
                    }
                    .navigationTitle("New transaction")
                    .onAppear {
                        if newTxAccountId.isEmpty, let first = model.accounts.first {
                            newTxAccountId = first.id
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateTx = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    let amt = Double(newTxAmount) ?? 0
                                    guard amt > 0, !newTxKey.isEmpty else { return }
                                    let iso = ISO8601DateFormatter().string(from: Date())
                                    do {
                                        try await model.createTransaction(
                                            accountId: newTxAccountId,
                                            category: newCategoryType,
                                            key: newTxKey.lowercased(),
                                            amount: amt,
                                            note: nil,
                                            postingTime: iso
                                        )
                                        newTxAmount = ""
                                        newTxKey = ""
                                        showCreateTx = false
                                        await model.loadTransactions(reset: true)
                                    } catch {}
                                }
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete selected rows?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { @MainActor in
                        switch model.selectedTab {
                        case .budget:
                            let rows = budgetRowsForDeletion()
                            selectedBudgetRows.removeAll()
                            highlightedBudgetRowId = nil
                            isDeletingSelection = true
                            defer { isDeletingSelection = false }
                            await model.deleteCategories(rows: rows)
                        case .transaction:
                            let ids = Array(selectedTxIds)
                            selectedTxIds.removeAll()
                            highlightedTransactionId = nil
                            isDeletingSelection = true
                            defer { isDeletingSelection = false }
                            await model.deleteTransactions(ids: ids)
                        case .yearlyReport:
                            break
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteConfirmationMessage)
            }
            .sheet(item: $activeEditSheet) { target in
                switch target {
                case .budget(let type, let row):
                    ChartBudgetRowEditSheet(
                        palette: palette,
                        budgetType: type,
                        row: row,
                        monthKeys: ChartBudgetMath.months,
                        onCommit: { name, amounts in
                            let k = row["key"] as? String ?? ""
                            await model.applyBudgetRowEdits(type: type, key: k, displayName: name, amountsByMonth: amounts)
                            selectedBudgetRows.removeAll()
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                case .transaction(let row):
                    ChartTransactionEditSheet(
                        palette: palette,
                        row: row,
                        onCommit: { category, key, amount, note, iso in
                            let id = row["id"] as? String ?? ""
                            await model.updateTransactionEdits(
                                txId: id,
                                category: category,
                                key: key,
                                amount: amount,
                                note: note,
                                postingTime: iso
                            )
                            selectedTxIds.removeAll()
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("Select one row", isPresented: $showEditSingleSelectionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Edit is available when exactly one row is selected.")
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: [payload.url])
            }
        }
    }

    private var accountSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    model.accountsExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accounts")
                            .font(.headline)
                        Text("Current Balances")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                    Group {
                        if model.isAccountSummaryLoading {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.22))
                                .frame(width: 100, height: 22)
                        } else {
                            Text(formatAccountSummaryMoney(model.currentBalance, code: model.userCurrency))
                                .font(.headline)
                                .foregroundStyle(Color.green)
                        }
                    }
                    Image(systemName: model.accountsExpanded ? "chevron.up" : "chevron.down")
                }
                .padding()
            }
            .buttonStyle(.plain)

            if model.accountsExpanded {
                Divider()
                if model.isAccountSummaryLoading, model.accounts.isEmpty {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        accountSummaryRowSkeleton
                    }
                } else {
                    ForEach(model.accounts) { a in
                        Button {
                            onAccountRowTap?(a.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(a.name ?? "—")
                                        .font(.subheadline.weight(.medium))
                                    Text("\(a.type ?? "asset") • \(a.currency ?? "USD")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Group {
                                    if model.isAccountSummaryLoading {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.secondary.opacity(0.22))
                                            .frame(width: 72, height: 18)
                                    } else {
                                        Text(formatAccountSummaryMoney(a.currentBalance ?? 0, code: (a.currency ?? "USD").uppercased()))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.green)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(palette.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.borderPrimary.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var accountSummaryRowSkeleton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 88, height: 10)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 72, height: 18)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var chartTabBar: some View {
        HStack(spacing: 8) {
            ForEach(ChartTab.allCases) { tab in
                Button {
                    model.selectedTab = tab
                } label: {
                    Text(tab.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(model.selectedTab == tab ? palette.brandGreenPrimary.opacity(0.35) : palette.inputInnerBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(palette.inputInnerBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(palette.borderPrimary.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var yearPicker: some View {
        Menu {
            ForEach((2020 ... (Calendar.current.component(.year, from: Date()) + 1)).reversed(), id: \.self) { y in
                Button(String(y)) { model.year = y }
            }
        } label: {
            HStack {
                Text(String(model.year))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.inputInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var chartActionsMenu: some View {
        Menu {
            if model.selectedTab != .yearlyReport {
                Button("Create") {
                    if model.selectedTab == .budget {
                        showCreateBudget = true
                    } else {
                        showCreateTx = true
                    }
                }
            }
            Button("Download") {
                exportCSV()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
    }

    private var hasSelection: Bool {
        switch model.selectedTab {
        case .budget: !selectedBudgetRows.isEmpty
        case .transaction: !selectedTxIds.isEmpty
        case .yearlyReport: false
        }
    }

    private var selectionCount: Int {
        switch model.selectedTab {
        case .budget: selectedBudgetRows.count
        case .transaction: selectedTxIds.count
        case .yearlyReport: 0
        }
    }

    private var canEditSelection: Bool { selectionCount == 1 }

    private var deleteConfirmationMessage: String {
        switch model.selectedTab {
        case .budget:
            return "This will permanently delete all budget data for the selected categories for this year. This action cannot be undone."
        case .transaction:
            return "This will permanently delete the selected transactions and remove all data associated with them. This action cannot be undone."
        case .yearlyReport:
            return ""
        }
    }

    private var selectionActionsBar: some View {
        HStack(spacing: 12) {
            Text(selectionCount == 1 ? "1 row selected" : "\(selectionCount) rows selected")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Edit") {
                presentEditSheet()
            }
            .disabled(!canEditSelection)
            Button("Delete", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 20, x: 0, y: 8)
    }

    private var deletingSelectionBar: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(palette.brandGreenPrimary)
            Text("Deleting…")
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 20, x: 0, y: 8)
    }

    private func presentEditSheet() {
        guard selectionCount == 1 else {
            showEditSingleSelectionAlert = true
            return
        }
        switch model.selectedTab {
        case .budget:
            guard let token = selectedBudgetRows.first else { return }
            guard let colon = token.firstIndex(of: ":") else { return }
            let kind = String(token[..<colon])
            let rowKey = String(token[token.index(after: colon)...])
            if kind == "income", let r = model.incomeRows.first(where: { ($0["key"] as? String) == rowKey }) {
                activeEditSheet = .budget(type: "income", row: r)
            } else if kind == "expense", let r = model.expenseRows.first(where: { ($0["key"] as? String) == rowKey }) {
                activeEditSheet = .budget(type: "expense", row: r)
            }
        case .transaction:
            guard let id = selectedTxIds.first,
                  let r = model.transactions.first(where: { ($0["id"] as? String) == id }) else { return }
            activeEditSheet = .transaction(row: r)
        case .yearlyReport:
            break
        }
    }

    private func toggleBudgetRowHighlight(_ id: String) {
        highlightedBudgetRowId = highlightedBudgetRowId == id ? nil : id
    }

    private func toggleTransactionRowHighlight(_ id: String) {
        highlightedTransactionId = highlightedTransactionId == id ? nil : id
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveNewCategory() async {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        dismissKeyboard()
        try? await Task.sleep(nanoseconds: 350_000_000)
        isSavingNewCategory = true
        await model.createCategory(
            type: newCategoryType,
            name: name,
            amount: nil
        )
        isSavingNewCategory = false
        newCategoryName = ""
        showCreateBudget = false
    }

    private func saveInlineEdits() async {
        guard !isInlineSaveInProgress else { return }
        isInlineSaveInProgress = true
        defer { isInlineSaveInProgress = false }

        dismissKeyboard()
        // Let the keyboard finish dismissing before showing the nav-bar spinner / starting network.
        try? await Task.sleep(nanoseconds: 350_000_000)

        switch model.selectedTab {
        case .budget:
            let edits = Array(pendingBudgetEdits.values)
            guard !edits.isEmpty else { return }
            let ok = await model.saveBudgetCellsBatch(edits)
            if ok {
                pendingBudgetEdits.removeAll()
            }
        case .transaction:
            let pairs = pendingNoteEdits.map { (id: $0.key, note: $0.value) }
            guard !pairs.isEmpty else { return }
            let ok = await model.saveTransactionNotesBatch(pairs)
            if ok {
                pendingNoteEdits.removeAll()
            }
        case .yearlyReport:
            break
        }
    }

    private var budgetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Summary")
                .font(.subheadline.weight(.bold))
            BudgetMatrixTable(
                title: "",
                rows: ChartBudgetMath.summaryRows(income: model.incomeRows, expense: model.expenseRows, year: model.year),
                editable: false,
                rowCategory: "summary",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: .constant([:]),
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )

            Text("Income Budgets")
                .font(.subheadline.weight(.bold))
            BudgetMatrixTable(
                title: "Income Budgets",
                rows: model.incomeRows + [ChartBudgetMath.monthlyTotalsRow(from: model.incomeRows)],
                editable: true,
                rowCategory: "income",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: $pendingBudgetEdits,
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )

            Text("Expense Budgets")
                .font(.subheadline.weight(.bold))
            BudgetMatrixTable(
                title: "Expense Budgets",
                rows: model.expenseRows + [ChartBudgetMath.monthlyTotalsRow(from: model.expenseRows)],
                editable: true,
                rowCategory: "expense",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: $pendingBudgetEdits,
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )
        }
    }

    private var yearlyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            BudgetMatrixTable(
                title: "Summary",
                rows: ChartBudgetMath.summaryRows(income: model.yearlyIncome, expense: model.yearlyExpense, year: model.year),
                editable: false,
                rowCategory: "summary",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: .constant([:]),
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )
            Text("Income")
                .font(.subheadline.weight(.bold))
            BudgetMatrixTable(
                title: "Yearly Income",
                rows: model.yearlyIncome + [ChartBudgetMath.monthlyTotalsRow(from: model.yearlyIncome)],
                editable: false,
                rowCategory: "income",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: .constant([:]),
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )
            Text("Expense")
                .font(.subheadline.weight(.bold))
            BudgetMatrixTable(
                title: "Yearly Expense",
                rows: model.yearlyExpense + [ChartBudgetMath.monthlyTotalsRow(from: model.yearlyExpense)],
                editable: false,
                rowCategory: "expense",
                selected: $selectedBudgetRows,
                monthKeys: ChartBudgetMath.months,
                pendingEdits: .constant([:]),
                accentColor: palette.brandGreenPrimary,
                highlightedRowId: highlightedBudgetRowId,
                onRowHighlight: toggleBudgetRowHighlight
            )
        }
    }

    private var transactionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransactionRowsList(
                rows: model.transactions,
                accounts: model.accounts,
                categoryName: { model.categoryDisplayName(key: $0) },
                selected: $selectedTxIds,
                pendingNoteEdits: $pendingNoteEdits,
                rowHighlightTint: palette.brandGreenPrimary,
                highlightedRowId: highlightedTransactionId,
                onRowHighlight: toggleTransactionRowHighlight
            )

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                if model.txLoading {
                    ProgressView()
                        .scaleEffect(0.85)
                }
                Button {
                    Task { await model.txPrevPage() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(model.txCurrentPage <= 1 || model.txLoading)

                Text("Page \(model.txCurrentPage)")
                    .font(.caption.weight(.semibold))

                Button {
                    Task { await model.txNextPage() }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.txHasMore || model.txLoading)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func budgetRowsForDeletion() -> [[String: Any]] {
        var out: [[String: Any]] = []
        for r in model.incomeRows {
            let k = r["key"] as? String ?? ""
            if selectedBudgetRows.contains("income:\(k)") {
                var x = r
                x["category"] = "income"
                out.append(x)
            }
        }
        for r in model.expenseRows {
            let k = r["key"] as? String ?? ""
            if selectedBudgetRows.contains("expense:\(k)") {
                var x = r
                x["category"] = "expense"
                out.append(x)
            }
        }
        return out
    }

    /// Account summary only: show ISO code + grouped amount (e.g. `GBP 9,000`), not `NumberFormatter.currency` symbols (£, €).
    private func formatAccountSummaryMoney(_ value: Double, code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let iso = trimmed.isEmpty ? "USD" : trimmed
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        let num = nf.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\(iso) \(num)"
    }

    private func exportCSV() {
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let y = model.year
        let sb = model.startingBalance
        let cb = model.currentBalance
        let csv: String
        let name: String
        switch model.selectedTab {
        case .budget:
            csv = ChartCSVExporter.budgetCSV(
                income: model.incomeRows,
                expense: model.expenseRows,
                startingBalance: sb,
                currentBalance: cb,
                year: y
            )
            name = "budget-data-\(y)-\(dateStr).csv"
        case .transaction:
            csv = ChartCSVExporter.transactionsCSV(rows: model.transactions) { model.categoryDisplayName(key: $0) }
            name = "transactions-\(dateStr).csv"
        case .yearlyReport:
            csv = ChartCSVExporter.yearlyCSV(
                income: model.yearlyIncome,
                expense: model.yearlyExpense,
                startingBalance: sb,
                currentBalance: cb,
                year: y
            )
            name = "yearly-report-\(y)-\(dateStr).csv"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? csv.data(using: .utf8)?.write(to: url)
        sharePayload = SharePayload(url: url)
    }
}

// MARK: - Share

struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

