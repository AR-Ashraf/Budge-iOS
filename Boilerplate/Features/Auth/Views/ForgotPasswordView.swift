import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AuthViewModel?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.xl) {
                    headerSection

                    if let viewModel {
                        formSection(viewModel)
                    }
                }
                .padding(UIConstants.Padding.section)
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .loadingOverlay(viewModel?.isLoading ?? false)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: authService)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image("BudgeLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 44)

            Text("Reset your password")
                .font(AppTheme.Typography.title)

            Text("Enter your email to receive a password reset link.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
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
                autocapitalization: .never,
                validationMessage: viewModel.emailError
            )
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            if let error = viewModel.generalError {
                ErrorBanner(message: error) {
                    didSend = false
                    viewModel.resetForm()
                }
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

