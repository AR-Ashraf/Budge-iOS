import SwiftUI

/// Sign up screen view
struct SignUpView: View {
    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: AuthViewModel?
    @State private var agreedToTerms = false
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

                    // Terms
                    termsSection

                    // Sign up button
                    if let viewModel {
                        signUpButton(viewModel)
                    }

                    // Login link
                    loginSection
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
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
                .frame(height: 44)

            Text("Get Started")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)

            Text("Take Control of Your Money. Stay on Budget.")
                .font(.system(size: 16, weight: .semibold))
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
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ),
                placeholder: "Full Name",
                icon: "person.fill",
                textContentType: .name,
                isRequired: true,
                validationMessage: viewModel.nameError
            )
            .onChange(of: viewModel.name) { _, _ in
                viewModel.validateName()
            }

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
                isRequired: true,
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
                isRequired: true,
                validationMessage: viewModel.passwordError
            )
            .onChange(of: viewModel.password) { _, _ in
                viewModel.validatePassword()
            }

            FormSecureField(
                label: "",
                text: Binding(
                    get: { viewModel.confirmPassword },
                    set: { viewModel.confirmPassword = $0 }
                ),
                placeholder: "Confirm Password",
                isRequired: true,
                validationMessage: viewModel.confirmPasswordError
            )
            .onChange(of: viewModel.confirmPassword) { _, _ in
                viewModel.validateConfirmPassword()
            }

            // Password requirements
            passwordRequirements

        }
    }

    private var passwordRequirements: some View {
        EmptyView()
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : AppTheme.Colors.tertiaryText)
                .font(.caption)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(met ? AppTheme.Colors.text : AppTheme.Colors.tertiaryText)
        }
    }

    private var termsSection: some View {
        Toggle(isOn: $agreedToTerms) {
            HStack(spacing: 0) {
                Text("I agree to the ")
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Terms of Service") {
                    // TODO: Open terms
                }

                Text(" and ")
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Privacy Policy") {
                    // TODO: Open privacy policy
                }
            }
            .font(AppTheme.Typography.caption)
        }
        .toggleStyle(.checkboxStyle)
    }

    private func signUpButton(_ viewModel: AuthViewModel) -> some View {
        PrimaryLoadingButton("Next") {
            if await viewModel.signUp() {
                dismiss()
            }
        }
        .disabled(!agreedToTerms || !viewModel.isSignUpFormValid)
    }

    private var loginSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Text("Already have an account?")
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                .font(.system(size: 14, weight: .semibold))

            Button("Login") {
                dismiss()
                router.present(sheet: .login)
            }
            .buttonStyle(.primary)
            .frame(height: 32)
        }
        .padding(.top, UIConstants.Spacing.md)
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.sm) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? .accentColor : AppTheme.Colors.secondaryText)
                .onTapGesture {
                    configuration.isOn.toggle()
                }

            configuration.label
        }
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkboxStyle: CheckboxToggleStyle { CheckboxToggleStyle() }
}

// MARK: - Preview

#Preview {
    SignUpView()
        .environment(AuthService(apiClient: APIClient()))
        .environment(Router.shared)
}
