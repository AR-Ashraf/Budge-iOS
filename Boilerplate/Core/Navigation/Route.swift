import Foundation

/// Type-safe route definitions for app navigation
/// All navigation destinations are defined here for compile-time safety
enum Route: Hashable {
    // MARK: - Main Routes

    case home
    case exampleList
    case exampleDetail(id: String)
    case exampleForm(item: ExampleItem?)
    case settings
    case profile
    /// My Accounts (web `/accounts` parity). Optional account id scroll target after Balance Sheet tap.
    case accounts(focusAccountId: String?)
    /// My Reminders (web `/reminders` parity).
    case reminders
    /// Post-auth onboarding (usually embedded from `RootView`; available for deep links).
    case onboarding

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .exampleList:
            hasher.combine("exampleList")
        case .exampleDetail(let id):
            hasher.combine("exampleDetail")
            hasher.combine(id)
        case .exampleForm(let item):
            hasher.combine("exampleForm")
            hasher.combine(item?.id)
        case .settings:
            hasher.combine("settings")
        case .profile:
            hasher.combine("profile")
        case .accounts(let focus):
            hasher.combine("accounts")
            hasher.combine(focus ?? "")
        case .reminders:
            hasher.combine("reminders")
        case .onboarding:
            hasher.combine("onboarding")
        }
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home),
             (.exampleList, .exampleList),
             (.settings, .settings),
             (.profile, .profile),
             (.onboarding, .onboarding):
            return true
        case (.exampleDetail(let lhsId), .exampleDetail(let rhsId)):
            return lhsId == rhsId
        case (.exampleForm(let lhsItem), .exampleForm(let rhsItem)):
            return lhsItem?.id == rhsItem?.id
        case (.accounts(let la), .accounts(let ra)):
            return la == ra
        case (.reminders, .reminders):
            return true
        default:
            return false
        }
    }
}

extension Route: CustomStringConvertible {
    var description: String { debugName }

    var debugName: String {
        switch self {
        case .home:
            return "Home"
        case .exampleList:
            return "ExampleList"
        case .exampleDetail(let id):
            return "ExampleDetail(\(id))"
        case .exampleForm(let item):
            return "ExampleForm(\(item?.id ?? "nil"))"
        case .settings:
            return "Settings"
        case .profile:
            return "Profile"
        case .accounts(let focus):
            return "Accounts(\(focus ?? "nil"))"
        case .reminders:
            return "Reminders"
        case .onboarding:
            return "OnboardingGate"
        }
    }
}

/// Sheet presentations (modal views)
enum Sheet: Identifiable {
    case login
    case signUp
    case forgotPassword

    var id: String {
        switch self {
        case .login:
            return "login"
        case .signUp:
            return "signUp"
        case .forgotPassword:
            return "forgotPassword"
        }
    }
}

/// Full screen cover presentations
enum FullScreenCover: Identifiable {
    case onboarding
    case imageViewer(url: URL)

    var id: String {
        switch self {
        case .onboarding:
            return "onboarding"
        case .imageViewer(let url):
            return "imageViewer_\(url.absoluteString)"
        }
    }
}

/// Alert presentations
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void

        init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.action = action
        }

        static func cancel(_ action: @escaping () -> Void = {}) -> AlertButton {
            AlertButton(title: "Cancel", role: .cancel, action: action)
        }

        static func destructive(_ title: String, action: @escaping () -> Void) -> AlertButton {
            AlertButton(title: title, role: .destructive, action: action)
        }

        static func `default`(_ title: String, action: @escaping () -> Void = {}) -> AlertButton {
            AlertButton(title: title, action: action)
        }
    }

    enum ButtonRole {
        case cancel
        case destructive
    }
}
