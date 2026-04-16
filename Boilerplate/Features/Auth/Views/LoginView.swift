import SwiftUI

/// Login screen view
struct LoginView: View {
    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: AuthViewModel?
    @State private var showToast = false
    @State private var toastMessage: String?
    @State private var isPasswordHidden = true
    private let emailTag = 1001
    private let passwordTag = 1002

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: UIConstants.Spacing.xl) {
                    // Header
                    headerSection

                    // Form
                    if let viewModel {
                        formSection(viewModel)
                    }

                    // Divider
                    dividerSection

                    // Social login
                    if let viewModel {
                        socialLoginSection(viewModel)
                    }

                    // Sign up link
                    signUpSection
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
        .toolbar {
            // no toolbar actions on login (match web)
        }
        .loadingOverlay(viewModel?.isLoading ?? false)
        .preferredColorScheme(.light)
        .toastOverlay(kind: .error, message: toastMessage, isPresented: $showToast)
        .onAppear {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: authService)
            }
        }
        .onChange(of: viewModel?.generalError) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            toastMessage = newValue
            withAnimation(.easeInOut(duration: 0.2)) {
                showToast = true
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image("Brand")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, UIConstants.Spacing.xl)
                .padding(.bottom, UIConstants.Spacing.xl)

            Text("Welcome")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)

            Text("Take Control of Your Money. Stay on Budget.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, UIConstants.Spacing.lg)
    }

    private func formSection(_ viewModel: AuthViewModel) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
            emailField(viewModel)
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            passwordField(viewModel)

            // Forgot password
            Button("Forgot Password?") {
                router.present(sheet: .forgotPassword)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
            .frame(maxWidth: .infinity, alignment: .center)

            // Login button
            PrimaryLoadingButton("Enter to Budge") {
                await submitLogin(viewModel)
            }
            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)
            .padding(.top, UIConstants.Spacing.md)
        }
    }

    private func emailField(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(!viewModel.email.isEmpty ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                ChainedTextField(
                    text: Binding(
                        get: { viewModel.email },
                        set: { viewModel.email = $0 }
                    ),
                    placeholder: "Email",
                    tag: emailTag,
                    nextTag: passwordTag,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalizationType: .none,
                    isSecureTextEntry: false,
                    returnKeyType: .next,
                    onSubmit: nil
                )

                if !viewModel.email.isEmpty {
                    Button {
                        viewModel.email = ""
                        HapticService.shared.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, UIConstants.Spacing.md)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(AppTheme.Colors.budgeAuthCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(emailBorderColor(viewModel), lineWidth: UIConstants.Border.standard)
            )
            .contentShape(Rectangle())

            if let msg = viewModel.emailError {
                Text(msg)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func passwordField(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(!viewModel.password.isEmpty ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                ChainedTextField(
                    text: Binding(
                        get: { viewModel.password },
                        set: { viewModel.password = $0 }
                    ),
                    placeholder: "Password",
                    tag: passwordTag,
                    nextTag: nil,
                    keyboardType: .default,
                    textContentType: .password,
                    autocapitalizationType: .none,
                    isSecureTextEntry: isPasswordHidden,
                    returnKeyType: .go,
                    onSubmit: {
                        Task { await submitLogin(viewModel) }
                    }
                )

                Button {
                    isPasswordHidden.toggle()
                    HapticService.shared.lightImpact()
                } label: {
                    Image(systemName: isPasswordHidden ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .padding(.horizontal, UIConstants.Spacing.md)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(AppTheme.Colors.budgeAuthCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(passwordBorderColor(viewModel), lineWidth: UIConstants.Border.standard)
            )
            .contentShape(Rectangle())

            if let msg = viewModel.passwordError {
                Text(msg)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func emailBorderColor(_ viewModel: AuthViewModel) -> Color {
        if viewModel.emailError != nil { return .red }
        if !viewModel.email.isEmpty { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
    }

    private func passwordBorderColor(_ viewModel: AuthViewModel) -> Color {
        if viewModel.passwordError != nil { return .red }
        if !viewModel.password.isEmpty { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
    }

    @MainActor
    private func submitLogin(_ viewModel: AuthViewModel) async {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if await viewModel.login() {
            dismiss()
        }
    }

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)

            Text("or")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .padding(.horizontal, UIConstants.Spacing.sm)

            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)
        }
        .padding(.vertical, UIConstants.Spacing.md)
    }

    private func socialLoginSection(_ viewModel: AuthViewModel) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
            // Google Sign In
            Button {
                Task {
                    if await viewModel.googleSignIn() {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    Image("GoogleIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppTheme.Colors.budgeAuthTextSecondary)
                    } else {
                        Text("Login With Google")
                    }
                }
            }
            .font(AppTheme.Typography.buttonLabel)
            .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.budgeAuthBackground)
            )
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    private var signUpSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Text("You don’t have any Budge Account?")
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                .font(.system(size: 14, weight: .semibold))

            Button("Register") {
                dismiss()
                router.present(sheet: .signUp)
            }
            .buttonStyle(.primary)
            .frame(height: 32)
        }
        .padding(.top, UIConstants.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthService(apiClient: APIClient()))
        .environment(Router.shared)
}
