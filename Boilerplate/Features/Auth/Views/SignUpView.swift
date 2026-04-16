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
    @State private var activeTag: Int? = nil
    @State private var isPasswordHidden = true
    @State private var isConfirmPasswordHidden = true

    private let nameTag = 2001
    private let emailTag = 2002
    private let passwordTag = 2003
    private let confirmPasswordTag = 2004

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

                    // Divider + Google sign up
                    dividerSection

                    if let viewModel {
                        googleSignUpButton(viewModel)
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
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                .frame(height: 120)
                .padding(.top, UIConstants.Spacing.xl)
                .padding(.bottom, UIConstants.Spacing.xl)

            Text("Get Started")
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
            nameField(viewModel)
            .onChange(of: viewModel.name) { _, _ in
                viewModel.validateName()
            }

            emailField(viewModel)
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            passwordField(viewModel)
            .onChange(of: viewModel.password) { _, _ in
                viewModel.validatePassword()
            }

            confirmPasswordField(viewModel)
            .onChange(of: viewModel.confirmPassword) { _, _ in
                viewModel.validateConfirmPassword()
            }

            // Password requirements
            passwordRequirements

        }
    }

    private func nameField(_ viewModel: AuthViewModel) -> some View {
        authTextField(
            icon: "person.fill",
            tag: nameTag,
            nextTag: emailTag,
            placeholder: "Full Name",
            text: Binding(get: { viewModel.name }, set: { viewModel.name = $0 }),
            keyboardType: .default,
            textContentType: .name,
            returnKeyType: .next,
            validationMessage: viewModel.nameError
        )
    }

    private func emailField(_ viewModel: AuthViewModel) -> some View {
        authTextField(
            icon: "envelope.fill",
            tag: emailTag,
            nextTag: passwordTag,
            placeholder: "Email",
            text: Binding(get: { viewModel.email }, set: { viewModel.email = $0 }),
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            returnKeyType: .next,
            autocapitalizationType: .none,
            validationMessage: viewModel.emailError
        )
    }

    private func passwordField(_ viewModel: AuthViewModel) -> some View {
        authSecureField(
            tag: passwordTag,
            nextTag: confirmPasswordTag,
            placeholder: "Password",
            text: Binding(get: { viewModel.password }, set: { viewModel.password = $0 }),
            isHidden: $isPasswordHidden,
            returnKeyType: .next,
            validationMessage: viewModel.passwordError
        )
    }

    private func confirmPasswordField(_ viewModel: AuthViewModel) -> some View {
        authSecureField(
            tag: confirmPasswordTag,
            nextTag: nil,
            placeholder: "Confirm Password",
            text: Binding(get: { viewModel.confirmPassword }, set: { viewModel.confirmPassword = $0 }),
            isHidden: $isConfirmPasswordHidden,
            returnKeyType: .go,
            validationMessage: viewModel.confirmPasswordError,
            onSubmit: {
                Task { await submitSignUp(viewModel) }
            }
        )
    }

    private func authTextField(
        icon: String,
        tag: Int,
        nextTag: Int?,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?,
        returnKeyType: UIReturnKeyType,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        validationMessage: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle((activeTag == tag || !text.wrappedValue.isEmpty) ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                ChainedTextField(
                    text: text,
                    placeholder: placeholder,
                    tag: tag,
                    nextTag: nextTag,
                    keyboardType: keyboardType,
                    textContentType: textContentType,
                    autocapitalizationType: autocapitalizationType,
                    isSecureTextEntry: false,
                    returnKeyType: returnKeyType,
                    onSubmit: nil,
                    onBeginEditing: { activeTag = tag },
                    onEndEditing: { if activeTag == tag { activeTag = nil } }
                )
            }
            .padding(.horizontal, UIConstants.Spacing.md)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(AppTheme.Colors.budgeAuthCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(borderColor(isActive: activeTag == tag, hasText: !text.wrappedValue.isEmpty, validationMessage: validationMessage), lineWidth: UIConstants.Border.standard)
            )

            if let validationMessage {
                Text(validationMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func authSecureField(
        tag: Int,
        nextTag: Int?,
        placeholder: String,
        text: Binding<String>,
        isHidden: Binding<Bool>,
        returnKeyType: UIReturnKeyType,
        validationMessage: String?,
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundStyle((activeTag == tag || !text.wrappedValue.isEmpty) ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                ChainedTextField(
                    text: text,
                    placeholder: placeholder,
                    tag: tag,
                    nextTag: nextTag,
                    keyboardType: .default,
                    textContentType: .password,
                    autocapitalizationType: .none,
                    isSecureTextEntry: isHidden.wrappedValue,
                    returnKeyType: returnKeyType,
                    onSubmit: onSubmit,
                    onBeginEditing: { activeTag = tag },
                    onEndEditing: { if activeTag == tag { activeTag = nil } }
                )

                Button {
                    isHidden.wrappedValue.toggle()
                    HapticService.shared.lightImpact()
                } label: {
                    Image(systemName: isHidden.wrappedValue ? "eye.slash.fill" : "eye.fill")
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
                    .stroke(borderColor(isActive: activeTag == tag, hasText: !text.wrappedValue.isEmpty, validationMessage: validationMessage), lineWidth: UIConstants.Border.standard)
            )

            if let validationMessage {
                Text(validationMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func borderColor(isActive: Bool, hasText: Bool, validationMessage: String?) -> Color {
        if validationMessage != nil { return .red }
        if hasText || isActive { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
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
            await submitSignUp(viewModel)
        }
        .disabled(!agreedToTerms || !viewModel.isSignUpFormValid)
    }

    private var dividerSection: some View {
        Rectangle()
            .fill(AppTheme.Colors.budgeAuthBorder)
            .frame(height: 2)
            .padding(.vertical, 2)
    }

    private func googleSignUpButton(_ viewModel: AuthViewModel) -> some View {
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
                Text("Sign Up With Google")
                    .font(AppTheme.Typography.buttonLabel)
            }
            .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: UIConstants.ButtonSize.medium)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.budgeAuthBackground)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func submitSignUp(_ viewModel: AuthViewModel) async {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard agreedToTerms else { return }
        if await viewModel.signUp() {
            dismiss()
        }
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
