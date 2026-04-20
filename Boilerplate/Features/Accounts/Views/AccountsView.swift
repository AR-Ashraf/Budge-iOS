import SwiftUI

/// Web `/accounts` parity: list, create, transfer, bulk delete, per-account edit (mobile card layout).
struct AccountsView: View {
    let focusAccountId: String?

    @Environment(OnboardingService.self) private var onboarding
    @Environment(AuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: AccountsViewModel?
    @State private var showCreate = false
    @State private var showTransfer = false
    @State private var editingRow: AccountDisplayRow?
    @State private var isSelecting = false
    @State private var selectedIds: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .tint(palette.brandGreenPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.screenBackground)
            }

            if isDeleting {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                ProgressView("Deleting…")
                    .tint(palette.brandGreenPrimary)
                    .padding(16)
                    .background(palette.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .background(palette.screenBackground)
        .navigationTitle("My Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil, let uid = authService.currentUser?.id {
                let vm = AccountsViewModel(uid: uid, onboarding: onboarding)
                viewModel = vm
                await vm.load()
            }
        }
        .sheet(isPresented: $showCreate) {
            if let vm = viewModel {
                AccountCreateSheet(palette: palette, viewModel: vm) {
                    showCreate = false
                }
            }
        }
        .sheet(isPresented: $showTransfer) {
            if let vm = viewModel {
                AccountTransferSheet(palette: palette, rows: vm.rows, viewModel: vm) {
                    showTransfer = false
                }
            }
        }
        .sheet(item: $editingRow) { row in
            if let vm = viewModel {
                AccountEditSheet(palette: palette, row: row, viewModel: vm) {
                    editingRow = nil
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel?.errorMessage = nil }
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete selected accounts?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await runBulkDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The main account cannot be deleted. Accounts with transactions cannot be deleted.")
        }
    }

    @ViewBuilder
    private func content(_ vm: AccountsViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if vm.isLoading, vm.rows.isEmpty {
                        ProgressView()
                            .tint(palette.brandGreenPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    ForEach(vm.rows) { row in
                        accountCard(vm: vm, row: row)
                            .id(row.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.rows.count) { _, _ in
                scrollToFocus(proxy: proxy, rows: vm.rows)
            }
            .onAppear {
                scrollToFocus(proxy: proxy, rows: vm.rows)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreate = true
                    } label: {
                        Label("New account", systemImage: "plus.circle")
                    }
                    Button {
                        showTransfer = true
                    } label: {
                        Label("Transfer money", systemImage: "arrow.left.arrow.right.circle")
                    }
                    Button {
                        isSelecting.toggle()
                        if !isSelecting { selectedIds.removeAll() }
                    } label: {
                        Label(isSelecting ? "Done selecting" : "Select accounts", systemImage: "checkmark.circle")
                    }
                    if isSelecting, !selectedIds.isEmpty {
                        Button(role: .destructive) {
                            if let def = vm.defaultAccountId, selectedIds.contains(def) {
                                vm.errorMessage = "Main account cannot be deleted"
                                return
                            }
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete selected", systemImage: "trash")
                        }
                        .disabled(isDeleting)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func scrollToFocus(proxy: ScrollViewProxy, rows: [AccountDisplayRow]) {
        guard let fid = focusAccountId, rows.contains(where: { $0.id == fid }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(fid, anchor: .center)
            }
        }
    }

    @ViewBuilder
    private func accountCard(vm: AccountsViewModel, row: AccountDisplayRow) -> some View {
        let isDefault = vm.defaultAccountId == row.id
        Button {
            if isSelecting {
                if selectedIds.contains(row.id) {
                    selectedIds.remove(row.id)
                } else {
                    selectedIds.insert(row.id)
                }
            } else {
                editingRow = row
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if isSelecting {
                    Image(systemName: selectedIds.contains(row.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIds.contains(row.id) ? palette.brandGreenPrimary : .secondary)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: row.type == "liability" ? "creditcard" : "wallet.pass")
                            .foregroundStyle(palette.bodyText.opacity(0.85))
                        Text(row.displayName)
                            .font(.headline)
                            .foregroundStyle(palette.bodyText)
                            .lineLimit(2)
                        if isDefault {
                            Text("Main")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(palette.brandGreenPrimary.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                        Text(formatMoney(row.currentBalance, code: row.currency))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(row.currentBalance >= 0 ? Color.green : Color.red)
                    }
                    labeledRow("Type", value: row.type.capitalized)
                    labeledRow("Currency", value: row.currency)
                    labeledRow("Starting balance", value: formatMoney(row.startingBalance, code: row.currency))
                    labeledRow("Account no.", value: row.accountNumber)
                    labeledRow("Bank", value: row.bankName)
                }
            }
            .padding(14)
            .background(palette.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.borderPrimary.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.bodyText)
        }
    }

    private func formatMoney(_ value: Double, code: String) -> String {
        let iso = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        let num = nf.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\(iso) \(num)"
    }

    @MainActor
    private func runBulkDelete() async {
        guard let vm = viewModel else { return }
        if let def = vm.defaultAccountId, selectedIds.contains(def) {
            vm.errorMessage = "Main account cannot be deleted"
            return
        }
        isDeleting = true
        defer {
            isDeleting = false
            isSelecting = false
        }
        await vm.deleteAccounts(ids: Array(selectedIds))
        selectedIds.removeAll()
    }
}

// MARK: - Create

private struct AccountCreateSheet: View {
    let palette: BudgeChatPalette
    let viewModel: AccountsViewModel
    let onClose: () -> Void

    @State private var name = ""
    @State private var type = "asset"
    @State private var currency = "USD"
    @State private var startingBalance = ""
    @State private var accountNumber = ""
    @State private var bankName = ""
    @State private var saving = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Asset").tag("asset")
                    Text("Liability").tag("liability")
                    Text("Income").tag("income")
                    Text("Expense").tag("expense")
                }
                Picker("Currency", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                    Text("BDT").tag("BDT")
                }
                TextField("Starting balance", text: $startingBalance)
                    .keyboardType(.decimalPad)
                TextField("Account number (optional)", text: $accountNumber)
                TextField("Bank (optional)", text: $bankName)
            }
            .navigationTitle("New account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView().tint(palette.brandGreenPrimary)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Couldn’t save", isPresented: Binding(
                get: { localError != nil },
                set: { if !$0 { localError = nil } }
            )) {
                Button("OK", role: .cancel) { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private func save() async {
        let sb = Double(startingBalance.trimmingCharacters(in: .whitespacesAndNewlines))
        saving = true
        defer { saving = false }
        do {
            try await viewModel.createAccount(
                name: name,
                type: type,
                currency: currency,
                startingBalance: sb,
                accountNumber: accountNumber.isEmpty ? nil : accountNumber,
                bankName: bankName.isEmpty ? nil : bankName
            )
            onClose()
        } catch {
            localError = error.localizedDescription
        }
    }
}

// MARK: - Transfer

private struct AccountTransferSheet: View {
    let palette: BudgeChatPalette
    let rows: [AccountDisplayRow]
    let viewModel: AccountsViewModel
    let onClose: () -> Void

    @State private var fromId = ""
    @State private var toId = ""
    @State private var amountText = ""
    @State private var note = ""
    @State private var saving = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("From", selection: $fromId) {
                    Text("Select").tag("")
                    ForEach(rows) { r in
                        Text(r.displayName).tag(r.id)
                    }
                }
                Picker("To", selection: $toId) {
                    Text("Select").tag("")
                    ForEach(rows) { r in
                        Text(r.displayName).tag(r.id)
                    }
                }
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if fromId.isEmpty, let first = rows.first { fromId = first.id }
                if toId.isEmpty, let second = rows.dropFirst().first { toId = second.id }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView().tint(palette.brandGreenPrimary)
                    } else {
                        Button("Transfer") {
                            Task { await transfer() }
                        }
                        .disabled(!canTransfer)
                    }
                }
            }
            .alert("Couldn’t transfer", isPresented: Binding(
                get: { localError != nil },
                set: { if !$0 { localError = nil } }
            )) {
                Button("OK", role: .cancel) { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private var canTransfer: Bool {
        !fromId.isEmpty && !toId.isEmpty && fromId != toId
            && (Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
    }

    private func transfer() async {
        let amt = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        saving = true
        defer { saving = false }
        do {
            try await viewModel.transfer(
                from: fromId,
                to: toId,
                amount: amt,
                note: note.isEmpty ? nil : note
            )
            onClose()
        } catch {
            localError = error.localizedDescription
        }
    }
}

// MARK: - Edit

private struct AccountEditSheet: View {
    let palette: BudgeChatPalette
    let row: AccountDisplayRow
    let viewModel: AccountsViewModel
    let onClose: () -> Void

    @State private var name: String
    @State private var type: String
    @State private var currency: String
    @State private var startingBalance: String
    @State private var accountNumber: String
    @State private var bankName: String
    @State private var saving = false
    @State private var localError: String?

    init(palette: BudgeChatPalette, row: AccountDisplayRow, viewModel: AccountsViewModel, onClose: @escaping () -> Void) {
        self.palette = palette
        self.row = row
        self.viewModel = viewModel
        self.onClose = onClose
        _name = State(initialValue: row.displayName)
        _type = State(initialValue: row.type)
        _currency = State(initialValue: row.currency)
        _startingBalance = State(initialValue: Self.formatNum(row.startingBalance))
        _accountNumber = State(initialValue: row.accountNumber == "—" ? "" : row.accountNumber)
        _bankName = State(initialValue: row.bankName == "—" ? "" : row.bankName)
    }

    private static func formatNum(_ d: Double) -> String {
        d == floor(d) ? String(format: "%.0f", d) : String(d)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Asset").tag("asset")
                    Text("Liability").tag("liability")
                    Text("Income").tag("income")
                    Text("Expense").tag("expense")
                }
                Picker("Currency", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                    Text("BDT").tag("BDT")
                }
                TextField("Starting balance", text: $startingBalance)
                    .keyboardType(.decimalPad)
                Text("Current balance is updated by transactions and cannot be edited here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Account number", text: $accountNumber)
                TextField("Bank", text: $bankName)
            }
            .navigationTitle("Edit account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView().tint(palette.brandGreenPrimary)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Couldn’t save", isPresented: Binding(
                get: { localError != nil },
                set: { if !$0 { localError = nil } }
            )) {
                Button("OK", role: .cancel) { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private func save() async {
        let sb = Double(startingBalance.trimmingCharacters(in: .whitespacesAndNewlines))
        saving = true
        defer { saving = false }
        do {
            try await viewModel.updateAccount(
                accountId: row.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                currency: currency,
                startingBalance: sb,
                accountNumber: accountNumber,
                bankName: bankName
            )
            onClose()
        } catch {
            localError = error.localizedDescription
        }
    }
}
