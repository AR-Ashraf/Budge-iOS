import FirebaseCore
import SwiftData
import SwiftUI

@main
struct BoilerplateApp: App {
    // MARK: - Dependencies

    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate

    private let router = Router.shared
    private let apiClient = APIClient()
    private let authService: AuthService
    private let onboardingService: OnboardingService
    private let analyticsService = AnalyticsService()
    private let chatService = ChatService()
    private let themeController = ThemeController()

    // MARK: - Initialization

    init() {
        FirebaseBootstrap.configureIfNeeded()
        authService = AuthService(apiClient: apiClient)
        onboardingService = OnboardingService()
        configureAppearance()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(apiClient)
                .environment(authService)
                .environment(onboardingService)
                .environment(analyticsService)
                .environment(chatService)
                .environment(themeController)
        }
        .modelContainer(SwiftDataContainer.shared)
    }

    // MARK: - Private Methods

    private func configureAppearance() {
        // Configure global appearance settings
        // Disable input assistant bar to avoid AutoLayout warnings on focus.
        let emptyGroups: [UIBarButtonItemGroup] = []
        UITextField.appearance().inputAssistantItem.leadingBarButtonGroups = emptyGroups
        UITextField.appearance().inputAssistantItem.trailingBarButtonGroups = emptyGroups
        UITextView.appearance().inputAssistantItem.leadingBarButtonGroups = emptyGroups
        UITextView.appearance().inputAssistantItem.trailingBarButtonGroups = emptyGroups
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var authService
    @Environment(OnboardingService.self) private var onboarding
    @Environment(ThemeController.self) private var themeController
    @Environment(\.scenePhase) private var scenePhase

    @State private var onboardingProfile: [String: Any]?
    @State private var isFetchingOnboardingProfile = false

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if !authService.hasCompletedInitialAuthCheck {
                    SplashView(animate: true)
                } else if authService.isAuthenticated {
                    if let onboardingProfile {
                        OnboardingGateView(initialProfile: onboardingProfile)
                    } else {
                        SplashView(animate: false)
                            .task {
                                await fetchOnboardingProfileIfNeeded()
                            }
                    }
                } else {
                    LoginView()
                }
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
        .preferredColorScheme(themeController.preferredColorScheme)
        .sheet(item: $router.presentedSheet) { sheet in
            sheetView(for: sheet)
        }
        .task {
            // Ensure Firebase is configured and auth listener is started after app launch.
            FirebaseBootstrap.configureIfNeeded()
            authService.start()

            // First launch: if nothing persisted yet, default to system (matches ``UserDefaultsWrapper``).
            let defaults = UserDefaults.standard
            if defaults.string(forKey: "selectedTheme") == nil {
                defaults.set("system", forKey: "selectedTheme")
            }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            // Reset cached onboarding routing profile on auth user changes.
            onboardingProfile = nil
            Task { await fetchOnboardingProfileIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let uid = authService.currentUser?.id else { return }
            switch phase {
            case .active:
                Task { await onboarding.updateUserPresence(uid: uid, isInApp: true, activeChatId: nil) }
            case .inactive, .background:
                Task { await onboarding.updateUserPresence(uid: uid, isInApp: false, activeChatId: nil) }
            @unknown default:
                break
            }
        }
    }

    private func fetchOnboardingProfileIfNeeded() async {
        guard authService.isAuthenticated, onboardingProfile == nil else { return }
        guard let uid = authService.currentUser?.id else { return }
        guard !isFetchingOnboardingProfile else { return }

        await MainActor.run { isFetchingOnboardingProfile = true }
        defer { Task { @MainActor in isFetchingOnboardingProfile = false } }

        do {
            let data = try await onboarding.fetchUserProfile(uid: uid)
            await MainActor.run {
                onboardingProfile = data
            }
        } catch {
            // If profile fetch fails, let the gate handle showing its error UI.
            await MainActor.run {
                onboardingProfile = [:]
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
        case .exampleList:
            ExampleListView()
        case .exampleDetail(let id):
            ExampleDetailView(itemId: id)
        case .exampleForm(let item):
            ExampleFormView(existingItem: item)
        case .settings:
            SettingsView()
        case .profile:
            ProfileView()
        case .accounts(let focusAccountId):
            AccountsView(focusAccountId: focusAccountId)
        case .reminders:
            RemindersView()
        case .onboarding:
            OnboardingGateView()
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: Sheet) -> some View {
        // Wrap sheets in a single NavigationStack to avoid nested NavigationStacks
        NavigationStack {
            switch sheet {
            case .login:
                LoginView()
            case .signUp:
                SignUpView()
            case .forgotPassword:
                ForgotPasswordView()
            }
        }
    }
}

// MARK: - Home View (Placeholder)

struct HomeView: View {
    @Environment(Router.self) private var router

    var body: some View {
        List {
            Section("Features") {
                Button("Example Feature") {
                    router.navigate(to: .exampleList)
                }
            }

            Section("Account") {
                Button("Settings") {
                    router.navigate(to: .settings)
                }
            }
        }
        .navigationTitle("Home")
    }
}

// MARK: - Onboarding View (Placeholder)

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Boilerplate")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your starting point for building great iOS apps")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            PrimaryButton(title: "Get Started") {
                UserDefaultsWrapper.hasCompletedOnboarding = true
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Profile View (Placeholder)

struct ProfileView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        List {
            if let user = authService.currentUser {
                Section {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}
