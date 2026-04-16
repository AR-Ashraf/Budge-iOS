import SwiftUI

/// Step-by-step category amounts for income or expense (web `financialPart` parity).
struct FinancialCategoryFlowView: View {
    enum FlowKind {
        case income
        case expense
    }

    let kind: FlowKind
    let categories: [FinancialCategorySeed]
    let uid: String
    let onboarding: OnboardingService

    var onIncomeCompleted: () async -> Void
    var onExpenseCompleted: () async -> Void

    @State private var step = 0
    @State private var amounts: [String: Double] = [:]
    @State private var amountText = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var current: FinancialCategorySeed { categories[step] }
    private var isLast: Bool { step >= categories.count - 1 }
    private var year: String { OnboardingService.currentBudgetYear }
    private var monthKey: String { OnboardingService.currentBudgetMonthKey }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                progressHeader

                Text(titleForKind)
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.text)

                Text(current.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, UIConstants.Spacing.md)
                    .frame(height: UIConstants.ButtonSize.medium)
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .fill(AppTheme.Colors.budgeAuthCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .stroke(AppTheme.Colors.budgeAuthBorder, lineWidth: UIConstants.Border.standard)
                    )
                    .onChange(of: step) { _, _ in
                        syncTextFromAmounts()
                    }
                    .onAppear {
                        syncTextFromAmounts()
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                }

                VStack(spacing: UIConstants.Spacing.md) {
                    if !isLast {
                        PrimaryButton(title: "Next", action: { Task { await goNext() } }, isLoading: isBusy)
                        Button("Skip") {
                            Task { await skipCurrent() }
                        }
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else {
                        PrimaryButton(title: "Complete", action: { Task { await completeLast() } }, isLoading: isBusy)
                        Button("Skip") {
                            Task { await skipLast() }
                        }
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Button("Skip all") {
                        Task { await skipAll() }
                    }
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)
                    .padding(.top, UIConstants.Spacing.sm)
                }
            }
            .padding(UIConstants.Padding.section)
        }
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
    }

    private var progressHeader: some View {
        HStack {
            Text("Step \(step + 1) of \(categories.count)")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
        }
    }

    private var titleForKind: String {
        switch kind {
        case .income:
            return "Monthly income"
        case .expense:
            return "Monthly expenses"
        }
    }

    private func syncTextFromAmounts() {
        let v = amounts[current.key] ?? 0
        if v == 0 {
            amountText = ""
        } else {
            amountText = Self.formatNumber(v)
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func parseCurrent() -> Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if normalized.isEmpty { return 0 }
        return Double(normalized)
    }

    private func goNext() async {
        errorMessage = nil
        guard let value = parseCurrent(), value >= 0 else {
            errorMessage = "Enter a valid amount."
            return
        }
        amounts[current.key] = value
        step += 1
    }

    private func skipCurrent() async {
        amounts[current.key] = 0
        step += 1
    }

    private func completeLast() async {
        errorMessage = nil
        guard let value = parseCurrent(), value > 0 else {
            errorMessage = "Enter a positive amount to continue."
            return
        }
        amounts[current.key] = value
        await persistAndFinish()
    }

    private func skipLast() async {
        amounts[current.key] = 0
        await persistAndFinish()
    }

    private func mergedAmounts() -> [String: Double] {
        var out: [String: Double] = [:]
        for c in categories {
            out[c.key] = amounts[c.key] ?? 0
        }
        return out
    }

    private func persistAndFinish() async {
        isBusy = true
        defer { isBusy = false }
        let data = mergedAmounts()
        do {
            switch kind {
            case .income:
                try await onboarding.saveBudgetAggregates(
                    uid: uid,
                    type: "income",
                    year: year,
                    amountsByKey: data,
                    monthKey: monthKey
                )
                await onIncomeCompleted()
            case .expense:
                try await onboarding.saveBudgetAggregates(
                    uid: uid,
                    type: "expense",
                    year: year,
                    amountsByKey: data,
                    monthKey: monthKey
                )
                try await onboarding.setHasFinancialData(uid: uid, true)
                await onExpenseCompleted()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func skipAll() async {
        isBusy = true
        defer { isBusy = false }
        let zero = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, 0.0) })
        do {
            switch kind {
            case .income:
                try await onboarding.saveBudgetAggregates(
                    uid: uid,
                    type: "income",
                    year: year,
                    amountsByKey: zero,
                    monthKey: monthKey
                )
                await onIncomeCompleted()
            case .expense:
                try await onboarding.saveBudgetAggregates(
                    uid: uid,
                    type: "expense",
                    year: year,
                    amountsByKey: zero,
                    monthKey: monthKey
                )
                try await onboarding.setHasFinancialData(uid: uid, true)
                await onExpenseCompleted()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
