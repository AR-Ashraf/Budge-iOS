import SwiftUI

/// Central post-auth onboarding router (React `routeAfterAuth` + `withOnboardingGuard` parity, excluding E2EE).
struct OnboardingGateView: View {
    @Environment(AuthService.self) private var authService
    @Environment(OnboardingService.self) private var onboarding

    @State private var profile: [String: Any] = [:]
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var lastLoggedPage: String?

    @State private var budgePhase: BudgePhase = .intro
    @State private var preFinancialPhase: PreFinancialPhase = .none
    @State private var financialSubStep: OnboardingFinancialSubStep = .income
    @State private var showJourney = false

    private enum BudgePhase {
        case intro
        case userType
    }

    private enum PreFinancialPhase {
        case none
        case initializationCompletion
    }

    private let hasInitialProfile: Bool

    init(initialProfile: [String: Any]? = nil) {
        let initial = initialProfile ?? [:]
        _profile = State(initialValue: initial)
        _isLoading = State(initialValue: initialProfile == nil)
        hasInitialProfile = initialProfile != nil
    }

    var body: some View {
        Group {
            if let loadError {
                onboardingErrorView(message: loadError)
            } else if isLoading {
                LoadingView()
            } else if authService.currentUser?.id != nil {
                gateContent
            } else {
                LoadingView()
            }
        }
        .task {
            if !hasInitialProfile {
                await loadProfile(showSpinner: true)
            } else {
                await MainActor.run { isLoading = false }
            }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            Task { await loadProfile(showSpinner: true) }
        }
    }

    @ViewBuilder
    private var gateContent: some View {
        if let uid = authService.currentUser?.id {
            if showJourney {
                JourneyCompletionView {
                    showJourney = false
                    Task { await loadProfile(showSpinner: false) }
                }
                .onAppear { logPageOnce(.journeyCompletion) }
            } else if preFinancialPhase == .initializationCompletion {
                InitializationCompletionView {
                    preFinancialPhase = .none
                }
                .onAppear { logPageOnce(.initializationCompletion) }
            } else {
                mainStep(uid: uid)
            }
        }
    }

    @ViewBuilder
    private func mainStep(uid: String) -> some View {
        let step = onboarding.nextMajorStep(from: profile)
        switch step {
        case .manageBalance:
            ManageBalanceView(
                onboarding: onboarding,
                uid: uid,
                onOptimisticContinue: { currencyCode, startingBalance in
                    await MainActor.run {
                        profile["currency"] = currencyCode
                        profile["startingBalance"] = startingBalance
                    }
                },
                onServerSynced: {
                    await loadProfile(showSpinner: false)
                }
            )
            .onAppear { logPageOnce(.manageBalance) }
        case .budgeIntro:
            budgeFlow(uid: uid)
        case .knowPlatform:
            KnowFromPlatformView(onboarding: onboarding, uid: uid) { selected in
                profile["platform"] = selected
                Task { await loadProfile(showSpinner: false) }
            }
            .onAppear { logPageOnce(.budgeSetupKnowFromPlatform) }
        case .whyUseBudge:
            WhyUseBudgeView(onboarding: onboarding, uid: uid) { selected in
                profile["usingReason"] = selected
                Task { await loadProfile(showSpinner: false) }
            }
            .onAppear { logPageOnce(.budgeSetupWhyUseBudge) }
        case .financialSetup:
            financialFlow(uid: uid)
        case .chat:
            ChatView()
                .onAppear { logPageOnce(.chat) }
        }
    }

    @ViewBuilder
    private func budgeFlow(uid: String) -> some View {
        switch budgePhase {
        case .intro:
            BudgeSetupIntroView {
                budgePhase = .userType
            }
            .onAppear { logPageOnce(.budgeSetupIntro) }
        case .userType:
            UserTypeView(onboarding: onboarding, uid: uid) { selected in
                applyLocalUserTypeSelection(selected)
                // Do not refetch here; routing is driven by local state for instant jump to chat.
            }
            .onAppear { logPageOnce(.budgeSetupUserType) }
        }
    }

    @ViewBuilder
    private func financialFlow(uid: String) -> some View {
        let userType = OnboardingUserType.fromFirestore(profile["userType"]) ?? .jobHolder
        let currency = (profile["currency"] as? String) ?? "USD"
        switch financialSubStep {
        case .income:
            FinancialSetupIncomeView(
                userType: userType,
                uid: uid,
                onboarding: onboarding,
                currency: currency,
                onIncomeCompleted: {
                    // After income, show `/financial-setup/completion` interstitial first.
                    OnboardingFinancialProgress.save(.postIncomeCelebration, uid: uid)
                    await MainActor.run {
                        financialSubStep = .postIncomeCelebration
                    }
                    await loadProfile(showSpinner: false)
                },
                onExpenseCompleted: {}
            )
            .onAppear { logPageOnce(.financialSetupIncome) }
        case .postIncomeCelebration:
            FinancialSetupCompletionView {
                // After `/financial-setup/completion`, continue to expense step.
                OnboardingFinancialProgress.save(.expense, uid: uid)
                financialSubStep = .expense
                // No profile refetch needed; we already mutated the sub-step locally.
            }
            .onAppear { logPageOnce(.financialSetupCompletion) }
        case .expense:
            FinancialSetupExpenseView(
                userType: userType,
                uid: uid,
                onboarding: onboarding,
                currency: currency,
                onIncomeCompleted: {},
                onExpenseCompleted: {
                    // After expense completion, go to journey completion (chat).
                    OnboardingFinancialProgress.clear(uid: uid)
                    profile["hasFinancialData"] = true
                    showJourney = true
                }
            )
            .onAppear { logPageOnce(.financialSetupExpense) }
        }
    }

    private func logPageOnce(_ page: OnboardingPage) {
#if DEBUG
        let name = page.rawValue
        guard lastLoggedPage != name else { return }
        lastLoggedPage = name
        Logger.shared.ui("Page: \(name)", level: .info)
#endif
    }

    private func onboardingErrorView(message: String) -> some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.warning)
            Text("Couldn’t load your profile")
                .font(AppTheme.Typography.headline)
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Try again", action: {
                Task { await loadProfile(showSpinner: true) }
            }, isFullWidth: false)
            Spacer()
        }
        .padding(UIConstants.Padding.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private func loadProfile(showSpinner: Bool) async {
        guard let uid = authService.currentUser?.id else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        if showSpinner {
            await MainActor.run {
                isLoading = true
                loadError = nil
            }
        } else {
            await MainActor.run {
                loadError = nil
            }
        }
        do {
            let data = try await onboarding.fetchUserProfile(uid: uid)
            await MainActor.run {
                profile = data
                if onboarding.nextMajorStep(from: data) == .financialSetup {
                    financialSubStep = OnboardingFinancialProgress.load(uid: uid)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func applyLocalUserTypeSelection(_ userType: OnboardingUserType) {
        profile["userType"] = userType.rawValue
        profile["hasFinancialData"] = true
    }
}
