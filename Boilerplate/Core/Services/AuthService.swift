import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import GoogleSignIn

/// Authentication service managing user session state
/// Handles Firebase login/signup/logout, and user state hydration
@Observable
final class AuthService {
    // MARK: - Properties

    /// Current authenticated user
    private(set) var currentUser: User?

    /// Whether the user is currently authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }

    /// Loading state for auth operations
    private(set) var isLoading = false

    /// Last authentication error
    private(set) var error: AuthError?

    private var didStart = false
    private(set) var hasCompletedInitialAuthCheck = false

    // MARK: - Initialization

    init(apiClient: APIClient) {
        // Important: Do NOT touch FirebaseAuth here. SwiftUI App init can run before
        // AppDelegate finished configuring Firebase, which triggers noisy warnings.
    }

    // MARK: - Public Methods

    /// Start observing Firebase auth state. Safe to call multiple times.
    /// Call this after Firebase has been configured (AppDelegate didFinishLaunching).
    func start() {
        if didStart { return }
        didStart = true

        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                await self.hydrateUser(firebaseUser)
                if !self.hasCompletedInitialAuthCheck {
                    self.hasCompletedInitialAuthCheck = true
                }
            }
        }

        Task { @MainActor in
            await hydrateUser(Auth.auth().currentUser)
            if !hasCompletedInitialAuthCheck {
                hasCompletedInitialAuthCheck = true
            }
        }
    }

    /// Sign in / sign up using Google (Firebase Auth).
    /// Mirrors the web behavior: authenticate with Google and ensure the Firestore user doc exists.
    @MainActor
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Missing Firebase clientID (is Firebase configured?)")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presentingVC = UIApplication.shared.topMostViewController else {
            throw AuthError.unknown("Unable to present Google Sign-In")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            let googleUser = result.user

            guard let idToken = googleUser.idToken?.tokenString else {
                throw AuthError.unknown("Missing Google ID token")
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleUser.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)

            // Ensure Firestore user document exists (merge-safe).
            let email = authResult.user.email ?? ""
            let name = authResult.user.displayName ?? googleUser.profile?.name ?? email
            let userDoc: [String: Any] = [
                "email": email,
                "name": name,
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await Firestore.firestore().collection("users").document(authResult.user.uid).setData(userDoc, merge: true)

            await hydrateUser(authResult.user)
        } catch let err as NSError {
            let authError = AuthError.fromFirebase(err)
            error = authError
            throw authError
        } catch {
            let authError = AuthError.unknown(error.localizedDescription)
            self.error = authError
            throw authError
        }
    }

    /// Check whether an email already has a sign-in method configured.
    func checkEmailExists(_ email: String) async throws -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Use server-side (Admin SDK) check via Cloud Function to avoid Firestore rules
        // and avoid FirebaseAuth email enumeration protection issues.
        let callable = Functions.functions(region: "us-central1").httpsCallable("checkEmailExists")
        do {
            let result = try await callable.call(["email": normalizedEmail])
            if let dict = result.data as? [String: Any], let exists = dict["exists"] as? Bool {
                return exists
            }
            throw AuthError.unknown("checkEmailExists: unexpected response (\(type(of: result.data)))")
        } catch let err as NSError {
            // Firebase Functions errors come back as NSError; surface useful debug details.
            // Common domains: FIRFunctionsErrorDomain / com.firebase.functions
            let domain = err.domain
            let code = err.code
            let message = err.localizedDescription
            let details = err.userInfo["details"] ?? err.userInfo[NSLocalizedFailureReasonErrorKey] ?? err.userInfo

            Logger.shared.auth("checkEmailExists failed: domain=\(domain) code=\(code) message=\(message) details=\(details)", level: .error)
            throw AuthError.unknown("checkEmailExists failed (\(domain) \(code)): \(message)")
        } catch {
            Logger.shared.auth("checkEmailExists failed: \(error.localizedDescription)", level: .error)
            throw AuthError.unknown("checkEmailExists failed: \(error.localizedDescription)")
        }
    }

    /// Sign in with email and password
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)

            guard result.user.isEmailVerified else {
                try? Auth.auth().signOut()
                let authError = AuthError.emailNotVerified
                self.error = authError
                throw authError
            }

            await hydrateUser(result.user)
            Logger.shared.auth("User signed in: \(normalizedEmail)", level: .info)
        } catch let err as AuthError {
            error = err
            throw err
        } catch let err as NSError {
            let authError = AuthError.fromFirebase(err)
            error = authError
            throw authError
        } catch {
            let authError = AuthError.unknown(error.localizedDescription)
            self.error = authError
            throw authError
        }
    }

    /// Sign up with name, email, and password
    @MainActor
    func signUp(name: String, email: String, password: String) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if try await checkEmailExists(normalizedEmail) {
                let authError = AuthError.emailAlreadyExists
                self.error = authError
                throw authError
            }

            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = trimmedName
            try await changeRequest.commitChanges()

            // Use a stable Firebase Hosting domain for verification links (React app may be down).
            let settings = ActionCodeSettings()
            settings.url = URL(string: "https://auth.mybudge.ai/verify-email")
            settings.handleCodeInApp = false
            try await result.user.sendEmailVerification(with: settings)

            let userDoc: [String: Any] = [
                "email": normalizedEmail,
                "name": trimmedName,
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await Firestore.firestore().collection("users").document(result.user.uid).setData(userDoc, merge: true)

            // Mirror web behavior: user signs up, verifies email, then logs in.
            try? Auth.auth().signOut()
            currentUser = nil

            Logger.shared.auth("User signed up: \(normalizedEmail)", level: .info)
        } catch let err as AuthError {
            error = err
            throw err
        } catch let err as NSError {
            let authError = AuthError.fromFirebase(err)
            error = authError
            throw authError
        } catch {
            let authError = AuthError.unknown(error.localizedDescription)
            self.error = authError
            throw authError
        }
    }

    /// Send a password reset email.
    @MainActor
    func sendPasswordReset(email: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            Logger.shared.auth("sendPasswordReset start for \(normalizedEmail)", level: .debug)

            // Match web behavior: verify account exists first.
            let exists = try await checkEmailExists(normalizedEmail)
            Logger.shared.auth("sendPasswordReset checkEmailExists=\(exists) for \(normalizedEmail)", level: .debug)
            guard exists else {
                let authError = AuthError.accountNotFound
                self.error = authError
                throw authError
            }

            let settings = ActionCodeSettings()
            // Dynamic Links is deprecated; use a web reset flow hosted on Firebase Hosting.
            settings.url = URL(string: "https://auth.mybudge.ai/reset-password")
            settings.handleCodeInApp = false

            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail, actionCodeSettings: settings)
            Logger.shared.auth("sendPasswordReset success for \(normalizedEmail)", level: .info)
        } catch let err as AuthError {
            error = err
            throw err
        } catch let err as NSError {
            Logger.shared.auth("sendPasswordReset failed (NSError): domain=\(err.domain) code=\(err.code) message=\(err.localizedDescription) userInfo=\(err.userInfo)", level: .error)
            // Extract FirebaseAuth backend error message when available.
            if
                let resp = err.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any],
                let backendMessage = resp["message"] as? String
            {
                if backendMessage == "RESET_PASSWORD_EXCEED_LIMIT" {
                    let authError = AuthError.unknown("Too many reset attempts. Please wait a bit and try again.")
                    error = authError
                    throw authError
                }
                if backendMessage.contains("DYNAMIC_LINK_NOT_ACTIVATED") || backendMessage.contains("FDL domain is not configured") {
                    // Dynamic Links is deprecated; don't block the reset flow. Send a standard reset email instead.
                    // This uses Firebase-hosted web handling (no in-app deep link).
                    Logger.shared.auth("Dynamic Links not available. Retrying password reset with web flow.", level: .warning)
                    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let settings = ActionCodeSettings()
                    settings.url = URL(string: "https://auth.mybudge.ai/reset-password")
                    settings.handleCodeInApp = false
                    try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail, actionCodeSettings: settings)
                    Logger.shared.auth("sendPasswordReset web-flow success for \(normalizedEmail)", level: .info)
                    return
                }
            }

            let authError = AuthError.fromFirebase(err)
            error = authError
            throw authError
        } catch {
            Logger.shared.auth("sendPasswordReset failed: \(error.localizedDescription)", level: .error)
            let authError = AuthError.unknown(error.localizedDescription)
            self.error = authError
            throw authError
        }
    }

    /// Sign out the current user
    @MainActor
    func signOut() async {
        // Clear local state first
        currentUser = nil
        try? Auth.auth().signOut()

        Logger.shared.auth("User signed out", level: .info)
    }

    @MainActor
    private func hydrateUser(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            currentUser = nil
            return
        }

        let uid = firebaseUser.uid
        let email = firebaseUser.email ?? ""
        var name = firebaseUser.displayName ?? ""
        var createdAt: Date? = nil

        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = snap.data() {
                if name.isEmpty, let storedName = data["name"] as? String { name = storedName }
                if let ts = data["createdAt"] as? Timestamp { createdAt = ts.dateValue() }
            }
        } catch {
            // Non-fatal; we can proceed with FirebaseAuth fields.
        }

        if name.isEmpty { name = email }

        currentUser = User(
            id: uid,
            name: name,
            email: email,
            avatarURL: nil,
            createdAt: createdAt
        )
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case emailNotVerified
    case accountNotFound
    case networkError
    case serverError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailAlreadyExists:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use a stronger password."
        case .emailNotVerified:
            return "Email is not verified. Please check and verify your email before logging in."
        case .accountNotFound:
            return "Account not found. Please sign up first."
        case .networkError:
            return "Network connection failed. Please check your internet."
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let message):
            return message
        }
    }

    static func fromFirebase(_ error: NSError) -> AuthError {
        // FirebaseAuth errors are surfaced as NSError with a code.
        // Map common cases to match the web app's UX.
        switch AuthErrorCode(_nsError: error).code {
        case .wrongPassword, .invalidEmail, .userNotFound, .invalidCredential:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyExists
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
