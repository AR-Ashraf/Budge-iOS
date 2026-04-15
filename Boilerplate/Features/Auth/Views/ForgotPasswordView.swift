import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AuthViewModel?
    @State private var didSend = false
    @State private var showToast = false
    @State private var toastMessage: String?

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
                .frame(height: 44)

            Text("Forgot Password")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)

            Text("Enter your email to receive a password reset link.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, UIConstants.Spacing.lg)
    }

    private func formSection(_ viewModel: AuthViewModel) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
            FormTextField(
                label: "Email",
                text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.email = $0 }
                ),
                placeholder: "Enter your email",
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalizationType: .none,
                validationMessage: viewModel.emailError
            )
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            if didSend {
                SuccessBanner(message: "Reset link sent! Please check your inbox.") {
                    didSend = false
                }
            }

            PrimaryLoadingButton("Send Reset Link") {
                if await viewModel.forgotPassword() {
                    didSend = true
                    // Match web flow: return to login after success.
                    dismiss()
                    router.present(sheet: .login)
                }
            }
            .disabled(viewModel.email.isEmpty || viewModel.emailError != nil)
            .padding(.top, UIConstants.Spacing.md)
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

