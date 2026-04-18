import SwiftUI

struct ManageBalanceView: View {
    let onboarding: OnboardingService
    let uid: String
    /// Applied on the main actor before persistence so routing can advance immediately.
    let onOptimisticContinue: (_ currencyCode: String, _ startingBalance: Double) async -> Void
    /// Called after Firestore + callables succeed; refresh profile from server (ciphertext fields).
    let onServerSynced: () async -> Void

    @State private var currency: CurrencyOption?
    @State private var balanceText = ""
    @State private var didSubmit = false
    @State private var errorMessage: String?
    @State private var showBalanceInfo = false

    private let currencies: [CurrencyOption] = [.usd, .bdt, .eur, .gbp]

    var body: some View {
        ZStack {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: UIConstants.Spacing.xl) {
                    headerSection

                    formSection
                }
                .cardStyleMinimal(
                    backgroundColor: AppTheme.Colors.budgeAuthCard,
                    cornerRadius: UIConstants.CornerRadius.extraLarge
                )
                .padding(UIConstants.Padding.section)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image("Brand")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, UIConstants.Spacing.xl)
                .padding(.bottom, UIConstants.Spacing.xl)

            Text("Manage your balance")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)

            Text("Choose your currency and starting balance.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, UIConstants.Spacing.lg)
    }

    private var formSection: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            currencyField
            balanceField

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(
                title: "Continue",
                action: { Task { await save() } },
                isLoading: false
            )
            .disabled(!canContinue)
            .padding(.top, UIConstants.Spacing.md)
        }
        .alert("Starting Balance", isPresented: $showBalanceInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This is the amount of money you currently have in your main account that you want to start tracking with Budge. You can add more accounts with different currencies and balances later.")
        }
    }

    private var currencyField: some View {
        Menu {
            ForEach(currencies, id: \.code) { opt in
                Button {
                    currency = opt
                } label: {
                    Label {
                        Text(opt.code)
                    } icon: {
                        opt.icon
                            .frame(width: UIConstants.IconSize.medium, height: UIConstants.IconSize.medium)
                    }
                }
            }
        } label: {
            HStack(spacing: UIConstants.Spacing.sm) {
                if let currency {
                    currency.icon
                        .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)
                        .frame(width: UIConstants.IconSize.medium, height: UIConstants.IconSize.medium)

                    Text(currency.code)
                        .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                } else {
                    Text("Select Currency")
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, UIConstants.Spacing.md)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(AppTheme.Colors.budgeAuthCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(currencyBorderColor, lineWidth: UIConstants.Border.standard)
            )
        }
        .buttonStyle(.plain)
    }

    private var balanceField: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            if let currency {
                currency.icon
                    .foregroundStyle(AppTheme.Colors.budgeGreenPrimary)
                    .frame(width: UIConstants.IconSize.medium, height: UIConstants.IconSize.medium)
            }

            TextField("Starting Balance", text: $balanceText)
                .keyboardType(.decimalPad)
                .autocapitalization(.none)
                .onChange(of: balanceText) { _, newValue in
                    // Allow digits and one optional decimal point; keep it lightweight (auth-field parity).
                    let unformatted = newValue.replacingOccurrences(of: ",", with: "")
                    if unformatted.isEmpty { return }
                    if !unformatted.matches(regex: #"^\d*\.?\d*$"#) {
                        balanceText = String(balanceText.dropLast())
                    }
                }

            Spacer()

            Button {
                showBalanceInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .accessibilityLabel("Starting balance info")
        }
        .padding(.horizontal, UIConstants.Spacing.md)
        .frame(height: UIConstants.ButtonSize.medium)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .fill(AppTheme.Colors.budgeAuthCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .stroke(balanceBorderColor, lineWidth: UIConstants.Border.standard)
        )
    }

    private var canContinue: Bool {
        if didSubmit { return false }
        guard currency != nil else { return false }
        return isValidStartingBalance()
    }

    private func isValidStartingBalance() -> Bool {
        let raw = balanceText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return false }
        guard raw.matches(regex: #"^\d*\.?\d*$"#) else { return false }
        guard let amount = Double(raw), amount >= 0 else { return false }
        return true
    }

    private var currencyBorderColor: Color {
        if currency != nil { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
    }

    private var balanceBorderColor: Color {
        if !balanceText.trimmingCharacters(in: .whitespaces).isEmpty { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
    }

    private func save() async {
        errorMessage = nil
        guard let currency else { return }
        guard !didSubmit else { return }
        let normalized = balanceText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value >= 0, !normalized.isEmpty else {
            errorMessage = "Enter a valid starting balance (0 or greater)."
            return
        }
        didSubmit = true
        await onOptimisticContinue(currency.code, value)
        Task(priority: .userInitiated) {
            do {
                try await onboarding.saveManageBalance(uid: uid, startingBalance: value, currency: currency.code)
                await onServerSynced()
            } catch {
                await MainActor.run {
                    didSubmit = false
                    errorMessage = error.localizedDescription
                }
                await onServerSynced()
            }
        }
    }
}

private enum CurrencyOption: String {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case bdt = "BDT"

    var code: String { rawValue }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .usd:
            Image(systemName: "dollarsign")
        case .eur:
            Image(systemName: "eurosign")
        case .gbp:
            Image(systemName: "sterlingsign")
        case .bdt:
            Image("bdt")
                .renderingMode(.template)
        }
    }
}

private extension String {
    func matches(regex: String) -> Bool {
        range(of: regex, options: .regularExpression) != nil
    }
}
