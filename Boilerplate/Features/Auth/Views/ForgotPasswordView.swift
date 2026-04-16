import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AuthViewModel?
    @State private var didSend = false
    @State private var showToast = false
    @State private var toastMessage: String?
    @State private var activeTag: Int? = nil

    private let emailTag = 3001

    var body: some View {
        ZStack {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: UIConstants.Spacing.xl) {
                    headerSection

                    if let viewModel {
                        formSection(viewModel)
                    }
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
                Button("Cancel") { dismiss() }
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

    private var headerSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image("Brand")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, UIConstants.Spacing.xl)
                .padding(.bottom, UIConstants.Spacing.xl)

            Text("Forgot Password")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)

            Text("Enter your email to receive a password reset link.")
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

            if didSend {
                SuccessBanner(message: "Reset link sent! Please check your inbox.") {
                    didSend = false
                }
            }

            PrimaryLoadingButton("Send Reset Link") {
                await submitReset(viewModel)
            }
            .disabled(viewModel.email.isEmpty || viewModel.emailError != nil)
            .padding(.top, UIConstants.Spacing.md)
        }
    }

    private func emailField(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle((activeTag == emailTag || !viewModel.email.isEmpty) ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                ChainedTextField(
                    text: Binding(get: { viewModel.email }, set: { viewModel.email = $0 }),
                    placeholder: "Enter your email",
                    tag: emailTag,
                    nextTag: nil,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalizationType: .none,
                    isSecureTextEntry: false,
                    returnKeyType: .go,
                    onSubmit: {
                        Task { await submitReset(viewModel) }
                    },
                    onBeginEditing: { activeTag = emailTag },
                    onEndEditing: { if activeTag == emailTag { activeTag = nil } }
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
                    .stroke(borderColor(hasText: !viewModel.email.isEmpty, isActive: activeTag == emailTag, validationMessage: viewModel.emailError), lineWidth: UIConstants.Border.standard)
            )

            if let msg = viewModel.emailError {
                Text(msg)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func borderColor(hasText: Bool, isActive: Bool, validationMessage: String?) -> Color {
        if validationMessage != nil { return .red }
        if hasText || isActive { return AppTheme.Colors.budgeGreenPrimary }
        return AppTheme.Colors.budgeAuthBorder
    }

    @MainActor
    private func submitReset(_ viewModel: AuthViewModel) async {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if await viewModel.forgotPassword() {
            didSend = true
            // Match web flow: return to login after success.
            dismiss()
            router.present(sheet: .login)
        }
    }
}

private struct SuccessBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.text)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(UIConstants.Spacing.md)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium))
    }
}

#Preview {
    ForgotPasswordView()
        .environment(AuthService(apiClient: APIClient()))
        .environment(Router.shared)
}

