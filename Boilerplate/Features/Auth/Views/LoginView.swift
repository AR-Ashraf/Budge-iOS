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
                    socialLoginSection

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
                .frame(height: 56)
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
            FormTextField(
                label: "",
                text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.email = $0 }
                ),
                placeholder: "Email",
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalizationType: .none,
                validationMessage: viewModel.emailError
            )
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            FormSecureField(
                label: "",
                text: Binding(
                    get: { viewModel.password },
                    set: { viewModel.password = $0 }
                ),
                placeholder: "Password",
                validationMessage: viewModel.passwordError
            )

            // Forgot password
            Button("Forgot Password?") {
                router.present(sheet: .forgotPassword)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
            .frame(maxWidth: .infinity, alignment: .center)

            // Login button
            PrimaryLoadingButton("Enter to Budge") {
                if await viewModel.login() {
                    dismiss()
                }
            }
            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)
            .padding(.top, UIConstants.Spacing.md)
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

    private var socialLoginSection: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            // Google Sign In
            Button {
                // TODO: Implement Google Sign In
            } label: {
                HStack {
                    Image("GoogleIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Login With Google")
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
