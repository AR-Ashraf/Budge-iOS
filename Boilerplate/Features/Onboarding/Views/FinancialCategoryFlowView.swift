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
    let currency: String

    var onIncomeCompleted: () async -> Void
    var onExpenseCompleted: () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("themePreference") private var themePreferenceRaw = "system"

    @State private var step = 0
    @State private var amounts: [String: Double] = [:]
    @State private var amountText = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var isNavigate = false
    @FocusState private var isAmountFocused: Bool

    private var current: FinancialCategorySeed { categories[step] }
    private var isLast: Bool { step >= categories.count - 1 }
    private var year: String { OnboardingService.currentBudgetYear }
    private var monthKey: String { OnboardingService.currentBudgetMonthKey }
    private var normalizedCurrency: String { currency.uppercased() }

    private var preferredColorSchemeOverride: ColorScheme? {
        switch themePreferenceRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorSchemeOverride ?? systemColorScheme
    }

    private var pageBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "#1D1D1F") : AppTheme.Colors.budgeAuthBackground
    }

    private var cardBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "#161617") : AppTheme.Colors.budgeAuthCard
    }

    private var pageTextPrimary: Color {
        effectiveColorScheme == .dark ? Color(hex: "#F5FFF6") : AppTheme.Colors.budgeAuthTextPrimary
    }

    private var pageTextSecondary: Color {
        effectiveColorScheme == .dark ? Color(hex: "#F5FFF6") : AppTheme.Colors.budgeAuthTextSecondary
    }

    private var pageBorder: Color {
        effectiveColorScheme == .dark ? Color(hex: "#333336") : AppTheme.Colors.budgeAuthBorder
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    financialCard(containerWidth: proxy.size.width)
                        .padding(.top, 24)

                    Spacer(minLength: 0)

                    if !isAmountFocused {
                        avatarPart(containerSize: proxy.size)
                            .padding(.bottom, 10)
                            .accessibilityHidden(true)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isAmountFocused = false
            }
        }
        .preferredColorScheme(preferredColorSchemeOverride)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            syncTextFromAmounts()
        }
        .onChange(of: step) { _, _ in
            syncTextFromAmounts()
        }
        .onChange(of: amountText) { _, newValue in
            formatAndStore(newValue)
        }
    }

    // MARK: - Web parity header strings

    private var currentMonthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "LLLL"
        return f.string(from: Date())
    }

    private var budgetTypeName: String {
        switch kind {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }

    private var progressValue: Double {
        guard categories.count > 1 else { return 100 }
        return (Double(step) / Double(categories.count - 1)) * 100
    }

    private var isNextDisabled: Bool {
        let v = amounts[current.key] ?? 0
        return !(v.isFinite && v > 0)
    }

    // MARK: - UI

    private var topHeader: some View {
        HStack(alignment: .center) {
            Image("mobileBrand")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            Spacer()

            HStack(spacing: 8) {
                Button(action: toggleThemePreference) {
                    Image(systemName: effectiveColorScheme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(pageTextSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .overlay(Circle().stroke(pageBorder, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle theme")

                HStack(spacing: 6) {
                    currencyLeading
                    Text(normalizedCurrency)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#04A10F"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: "#009F2B33"))
                        .overlay(Capsule(style: .continuous).stroke(Color(hex: "#04A10F"), lineWidth: 1))
                )
            }
        }
    }

    @ViewBuilder
    private var currencyLeading: some View {
        switch normalizedCurrency {
        case "EUR":
            Image(systemName: "eurosign")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#04A10F"))
        case "GBP":
            Image(systemName: "sterlingsign")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#04A10F"))
        case "BDT":
            Text("৳")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#04A10F"))
        default:
            Image(systemName: "dollarsign")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#04A10F"))
        }
    }

    private func financialCard(containerWidth: CGFloat) -> some View {
        let cardWidth: CGFloat = horizontalSizeClass == .regular ? 520 : min(containerWidth * 0.90, 420)

        return VStack(spacing: 16) {
            Text("\(currentMonthName) \(budgetTypeName) Budgets")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(pageTextPrimary)
                .multilineTextAlignment(.center)

            ProgressView(value: progressValue, total: 100)
                .progressViewStyle(.linear)
                .tint(AppTheme.Colors.budgeGreenPrimary)
                .frame(height: 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .animation(.easeInOut(duration: 0.35), value: progressValue)

            VStack(spacing: 16) {
                Text(current.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(pageTextPrimary)
                    .multilineTextAlignment(.center)

                TextField("Input Here", text: $amountText)
                    .focused($isAmountFocused)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(pageBackground)
                    )
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)))
            .animation(.easeInOut(duration: 0.5), value: step)

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .center) {
                Button("Skip All") {
                    Task { await skipAll() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pageTextSecondary)
                .disabled(isBusy)

                Spacer()

                HStack(spacing: 16) {
                    Button("Skip this category") {
                        Task { await skipCurrentOrFinishIfLast() }
                    }
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(pageTextSecondary)
                    .disabled(isBusy)

                    SmallPillButton(
                        title: isLast ? "Complete" : "Next",
                        isLoading: isBusy,
                        isDisabled: isNextDisabled || isBusy
                    ) {
                        Task { await nextOrComplete() }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(pageBorder, lineWidth: 1)
        )
        .offset(y: isNavigate ? -100 : 0)
        .opacity(isNavigate ? 0 : 1)
        .animation(.easeInOut(duration: 0.6), value: isNavigate)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 40)
    }

    private func avatarPart(containerSize: CGSize) -> some View {
        // Mobile parity: mascot + bubble bottom-right.
        let mascotSize: CGFloat = horizontalSizeClass == .regular ? 160 : 112

        return ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                speechBubble(text: "Input Your Monthly \(budgetTypeName) Budgets", availableWidth: containerSize.width)

                Image("financialSetup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: mascotSize, height: mascotSize)
            }
            .padding(.trailing, 16)
        }
        .offset(x: isNavigate ? -500 : 0)
        .opacity(isNavigate ? 0 : 1)
        .animation(.easeInOut(duration: 0.6), value: isNavigate)
    }

    private func speechBubble(text: String, availableWidth: CGFloat) -> some View {
        let maxBubbleWidth = min(availableWidth - (UIConstants.Padding.section * 2), 320)
        let bubbleFill = effectiveColorScheme == .dark ? Color(hex: "#161617") : Color(hex: "#FAFAFC")
        let bubbleStroke = effectiveColorScheme == .dark ? Color(hex: "#424245") : Color(hex: "#D2D2D7")

        return ZStack(alignment: .bottomTrailing) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pageTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(width: maxBubbleWidth, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(bubbleFill)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(bubbleStroke, lineWidth: 1)
                )

            speechTail(fill: bubbleFill, stroke: bubbleStroke)
                .offset(x: -28, y: 8)
        }
    }

    func speechTail(fill: Color, stroke: Color) -> some View {
        ZStack {
            Rectangle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
            Rectangle()
                .strokeBorder(stroke, lineWidth: 1)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 22, height: 11)
        .clipped()
    }

    private func syncTextFromAmounts() {
        let v = amounts[current.key] ?? 0
        if v == 0 {
            amountText = ""
        } else {
            amountText = Self.formatGrouped(v)
        }
    }

    private static func formatGrouped(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = value.rounded() == value ? 0 : 2
        f.groupingSeparator = ","
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func parseCurrent() -> Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if normalized.isEmpty { return 0 }
        return Double(normalized)
    }

    private func nextOrComplete() async {
        errorMessage = nil
        guard let value = parseCurrent(), value >= 0 else {
            errorMessage = "Enter a valid amount."
            return
        }
        amounts[current.key] = value

        if isLast {
            // Block completion if current is not positive (web parity).
            guard value > 0 else {
                errorMessage = "Enter a positive amount to continue."
                return
            }
            await persistAndFinishNonBlocking()
        } else {
            // Keep keyboard open while advancing to the next step.
            isAmountFocused = true
            withAnimation(.easeInOut(duration: 0.35)) {
                step += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isAmountFocused = true
            }
        }
    }

    private func skipCurrentOrFinishIfLast() async {
        amounts[current.key] = 0
        if isLast {
            await persistAndFinishNonBlocking()
        } else {
            // Keep keyboard open while advancing to the next step.
            isAmountFocused = true
            withAnimation(.easeInOut(duration: 0.35)) {
                step += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isAmountFocused = true
            }
        }
    }

    private func mergedAmounts() -> [String: Double] {
        var out: [String: Double] = [:]
        for c in categories {
            out[c.key] = amounts[c.key] ?? 0
        }
        return out
    }

    private func persistAndFinishNonBlocking() async {
        if isBusy { return }
        isBusy = true
        let data = mergedAmounts()

        // Fire-and-forget persistence; do not block routing (web parity).
        Task.detached(priority: .utility) {
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
                case .expense:
                    try await onboarding.saveBudgetAggregates(
                        uid: uid,
                        type: "expense",
                        year: year,
                        amountsByKey: data,
                        monthKey: monthKey
                    )
                    try await onboarding.setHasFinancialData(uid: uid, true)
                }
            } catch {
                // non-blocking
            }
        }

        // Smooth transition before routing.
        isNavigate = true
        try? await Task.sleep(nanoseconds: 400_000_000)

        switch kind {
        case .income:
            await onIncomeCompleted()
        case .expense:
            await onExpenseCompleted()
        }
    }

    private func skipAll() async {
        guard !isBusy else { return }
        let zero = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, 0.0) })
        for (k, v) in zero { amounts[k] = v }
        syncTextFromAmounts()
        await persistAndFinishNonBlocking()
    }

    private func formatAndStore(_ raw: String) {
        guard !isBusy else { return }
        let unformatted = raw.replacingOccurrences(of: ",", with: "")
        if unformatted.isEmpty {
            amounts[current.key] = 0
            if amountText != "" { amountText = "" }
            return
        }
        // Accept only digits and optional decimal point.
        let allowed = CharacterSet(charactersIn: "0123456789.")
        if unformatted.rangeOfCharacter(from: allowed.inverted) != nil {
            // reject invalid characters
            amountText = Self.formatGrouped(amounts[current.key] ?? 0)
            return
        }
        let parts = unformatted.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count > 2 { return }
        let intPart = String(parts.first ?? "")
        let fracPart = parts.count == 2 ? String(parts[1]) : nil

        // Format integer part with grouping.
        let intVal = Double(intPart) ?? 0
        let intFormatted = Self.formatGrouped(intVal).components(separatedBy: ".").first ?? intPart
        var formatted = intFormatted
        if let fracPart {
            formatted += "." + String(fracPart.prefix(2))
        }
        if formatted != amountText {
            amountText = formatted
        }
        amounts[current.key] = Double(unformatted) ?? 0
        errorMessage = nil
    }

    private func toggleThemePreference() {
        switch themePreferenceRaw {
        case "light":
            themePreferenceRaw = "dark"
        case "dark":
            themePreferenceRaw = "light"
        default:
            // First override from system: choose opposite for clear visible feedback.
            themePreferenceRaw = (systemColorScheme == .dark) ? "light" : "dark"
        }
    }
}

// MARK: - Components

private struct SmallPillButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let textColor: Color = {
            if isDisabled || isLoading {
                return colorScheme == .dark ? Color(white: 0.75) : Color.gray
            }
            return AppTheme.Colors.budgeGreenDarkText
        }()
        Button(action: {
            guard !isLoading, !isDisabled else { return }
            HapticService.shared.buttonTap()
            action()
        }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(textColor)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.25) : AppTheme.Colors.budgeGreenPrimary)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

// Curved tail removed; financial setup uses same bubble tail as Budge setup pages.
