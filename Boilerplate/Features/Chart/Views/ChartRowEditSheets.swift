import SwiftUI
import UIKit

// MARK: - Budget category row (monthly amounts + display name)

struct ChartBudgetRowEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let palette: BudgeChatPalette
    let budgetType: String
    let row: [String: Any]
    let monthKeys: [String]
    let onCommit: (_ displayName: String, _ amountsByMonth: [String: Double]) async -> Void

    @State private var displayName: String = ""
    @State private var monthTexts: [String: String] = [:]
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $displayName)
                }
                Section("Monthly amounts") {
                    ForEach(monthKeys, id: \.self) { m in
                        HStack {
                            Text(m)
                                .frame(width: 40, alignment: .leading)
                            TextField("0", text: Binding(
                                get: { monthTexts[m] ?? "" },
                                set: { monthTexts[m] = $0 }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.screenBackground)
            .navigationTitle("Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveBudgetEdits() }
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear {
                let title = row["title"] ?? row["name"] ?? row["key"] ?? ""
                displayName = String(describing: title)
                for m in monthKeys {
                    let v = ChartBudgetMath.doubleValue(row, key: m)
                    monthTexts[m] = v == 0 ? "" : String(format: "%.0f", v)
                }
            }
        }
    }

    @MainActor
    private func saveBudgetEdits() async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var amounts: [String: Double] = [:]
        for m in monthKeys {
            let raw = monthTexts[m]?.replacingOccurrences(of: ",", with: "") ?? ""
            amounts[m] = Double(raw) ?? 0
        }
        dismissKeyboardForSheet()
        try? await Task.sleep(nanoseconds: 350_000_000)
        isSaving = true
        await onCommit(name, amounts)
        isSaving = false
        dismiss()
    }
}

// MARK: - Transaction

struct ChartTransactionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let palette: BudgeChatPalette
    let row: [String: Any]
    let onCommit: (_ category: String, _ key: String, _ amount: Double, _ note: String, _ postingISO: String) async -> Void

    @State private var category: String = "expense"
    @State private var key: String = ""
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var postingDate: Date = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Category", selection: $category) {
                        Text("Income").tag("income")
                        Text("Expense").tag("expense")
                    }
                }
                Section("Details") {
                    TextField("Category key", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
                Section("Date") {
                    DatePicker("Posted", selection: $postingDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.screenBackground)
            .navigationTitle("Edit transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveTransactionEdits() }
                        }
                    }
                }
            }
            .onAppear {
                category = (row["category"] as? String)?.lowercased() == "income" ? "income" : "expense"
                key = (row["key"] as? String) ?? ""
                note = (row["note"] as? String) ?? ""
                let dep = ChartBudgetMath.doubleValue(row, key: "deposit")
                let pay = ChartBudgetMath.doubleValue(row, key: "payment")
                let mag = max(dep, pay)
                amountText = mag == 0 ? "" : String(format: "%.0f", mag)
                if let s = row["date"] as? String, let d = Self.parsePostingDate(s) {
                    postingDate = d
                }
            }
        }
    }

    @MainActor
    private func saveTransactionEdits() async {
        let amt = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        guard amt > 0, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let iso = ISO8601DateFormatter().string(from: postingDate)
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        dismissKeyboardForSheet()
        try? await Task.sleep(nanoseconds: 350_000_000)
        isSaving = true
        await onCommit(category, k, amt, note, iso)
        isSaving = false
        dismiss()
    }

    private static func parsePostingDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f.date(from: s)
    }
}

private func dismissKeyboardForSheet() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
