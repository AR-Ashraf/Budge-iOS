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
            await loadProfile()
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            Task { await loadProfile() }
        }
    }

    @ViewBuilder
    private var gateContent: some View {
        if let uid = authService.currentUser?.id {
            if showJourney {
                JourneyCompletionView {
                    showJourney = false
                    Task { await loadProfile() }
                }
                .onAppear { logPageOnce("JourneyCompletion") }
            } else if preFinancialPhase == .initializationCompletion {
                InitializationCompletionView {
                    preFinancialPhase = .none
                }
                .onAppear { logPageOnce("InitializationCompletion") }
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
            ManageBalanceView(onboarding: onboarding, uid: uid) {
                await loadProfile()
            }
            .onAppear { logPageOnce("ManageBalance") }
        case .budgeIntro:
            budgeFlow(uid: uid)
        case .knowPlatform:
            KnowFromPlatformView(onboarding: onboarding, uid: uid) {
                await loadProfile()
            }
            .onAppear { logPageOnce("KnowFromPlatform") }
        case .whyUseBudge:
            WhyUseBudgeView(onboarding: onboarding, uid: uid) {
                await loadProfile()
                await MainActor.run {
                    preFinancialPhase = .initializationCompletion
                }
            }
            .onAppear { logPageOnce("WhyUseBudge") }
        case .financialSetup:
            financialFlow(uid: uid)
        case .chat:
            ChatView()
                .onAppear { logPageOnce("Chat") }
        }
    }

    @ViewBuilder
    private func budgeFlow(uid: String) -> some View {
        switch budgePhase {
        case .intro:
            BudgeSetupIntroView {
                budgePhase = .userType
            }
            .onAppear { logPageOnce("BudgeSetupIntro") }
        case .userType:
            UserTypeView(onboarding: onboarding, uid: uid) {
                await loadProfile()
            }
            .onAppear { logPageOnce("UserType") }
        }
    }

    @ViewBuilder
    private func financialFlow(uid: String) -> some View {
        let userType = OnboardingUserType.fromFirestore(profile["userType"]) ?? .jobHolder
        switch financialSubStep {
        case .income:
            FinancialSetupIncomeView(
                userType: userType,
                uid: uid,
                onboarding: onboarding,
                onIncomeCompleted: {
                    OnboardingFinancialProgress.save(.postIncomeCelebration, uid: uid)
                    await MainActor.run {
                        financialSubStep = .postIncomeCelebration
                    }
                    await loadProfile()
                },
                onExpenseCompleted: {}
            )
            .onAppear { logPageOnce("FinancialSetupIncome") }
        case .postIncomeCelebration:
            FinancialSetupCompletionView {
                OnboardingFinancialProgress.save(.expense, uid: uid)
                financialSubStep = .expense
            }
            .onAppear { logPageOnce("FinancialSetupCompletion") }
        case .expense:
            FinancialSetupExpenseView(
                userType: userType,
                uid: uid,
                onboarding: onboarding,
                onIncomeCompleted: {},
                onExpenseCompleted: {
                    OnboardingFinancialProgress.clear(uid: uid)
                    await MainActor.run {
                        showJourney = true
                    }
                }
            )
            .onAppear { logPageOnce("FinancialSetupExpense") }
        }
    }

    private func logPageOnce(_ name: String) {
#if DEBUG
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
                Task { await loadProfile() }
            }, isFullWidth: false)
            Spacer()
        }
        .padding(UIConstants.Padding.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private func loadProfile() async {
        guard let uid = authService.currentUser?.id else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        await MainActor.run {
            isLoading = true
            loadError = nil
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
}
