import SwiftUI

/// Styled text field for forms with label, placeholder, and validation
struct FormTextField: View {
    // MARK: - Properties

    let label: String
    @Binding var text: String

    var placeholder: String = ""
    var icon: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var returnKeyType: UIReturnKeyType = .default
    var isFirstResponder: Binding<Bool> = .constant(false)
    var onReturn: (() -> Void)?
    var isRequired: Bool = false
    var validationMessage: String?
    var helpText: String?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            // Text field
            HStack(spacing: UIConstants.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle((isFirstResponder.wrappedValue || !text.isEmpty) ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                        .frame(width: UIConstants.IconSize.medium)
                }

                NoAssistantTextField(
                    text: $text,
                    placeholder: placeholder.isEmpty ? label : placeholder,
                    isFirstResponder: isFirstResponder,
                    keyboardType: keyboardType,
                    textContentType: textContentType,
                    autocapitalizationType: autocapitalizationType,
                    isSecureTextEntry: false,
                    returnKeyType: returnKeyType,
                    onReturn: onReturn
                )

                if !text.isEmpty {
                    Button {
                        text = ""
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
                    .stroke(borderColor, lineWidth: UIConstants.Border.standard)
            )

            // Help text or validation message
            if let validationMessage {
                Text(validationMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            } else if let helpText {
                Text(helpText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    // MARK: - Computed Properties

    private var borderColor: Color {
        if validationMessage != nil {
            return .red
        }
        if !text.isEmpty {
            return AppTheme.Colors.budgeGreenPrimary
        }
        if isFirstResponder.wrappedValue {
            return AppTheme.Colors.budgeGreenPrimary
        }
        return AppTheme.Colors.budgeAuthBorder
    }
}

/// Secure text field for passwords
struct FormSecureField: View {
    // MARK: - Properties

    let label: String
    @Binding var text: String

    var placeholder: String = ""
    var isRequired: Bool = false
    var validationMessage: String?
    var returnKeyType: UIReturnKeyType = .default
    var isFirstResponder: Binding<Bool> = .constant(false)
    var onReturn: (() -> Void)?

    // MARK: - State

    @State private var isSecure = true

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            // Secure field
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundStyle((isFirstResponder.wrappedValue || !text.isEmpty) ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.secondaryText)
                    .frame(width: UIConstants.IconSize.medium)

                Group {
                    if isSecure {
                        NoAssistantTextField(
                            text: $text,
                            placeholder: placeholder.isEmpty ? label : placeholder,
                            isFirstResponder: isFirstResponder,
                            keyboardType: .default,
                            textContentType: .password,
                            autocapitalizationType: .none,
                            isSecureTextEntry: true,
                            returnKeyType: returnKeyType,
                            onReturn: onReturn
                        )
                    } else {
                        NoAssistantTextField(
                            text: $text,
                            placeholder: placeholder.isEmpty ? label : placeholder,
                            isFirstResponder: isFirstResponder,
                            keyboardType: .default,
                            textContentType: .password,
                            autocapitalizationType: .none,
                            isSecureTextEntry: false,
                            returnKeyType: returnKeyType,
                            onReturn: onReturn
                        )
                    }
                }

                Button {
                    isSecure.toggle()
                    HapticService.shared.lightImpact()
                } label: {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
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
                    .stroke(borderColor, lineWidth: UIConstants.Border.standard)
            )

            // Validation message
            if let validationMessage {
                Text(validationMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Computed Properties

    private var borderColor: Color {
        if validationMessage != nil {
            return .red
        }
        if !text.isEmpty {
            return AppTheme.Colors.budgeGreenPrimary
        }
        if isFirstResponder.wrappedValue {
            return AppTheme.Colors.budgeGreenPrimary
        }
        return AppTheme.Colors.budgeAuthBorder
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            FormTextField(
                label: "Email",
                text: .constant(""),
                placeholder: "Enter your email",
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalizationType: .none,
                isRequired: true
            )

            FormTextField(
                label: "Username",
                text: .constant("john_doe"),
                placeholder: "Enter username",
                icon: "person.fill",
                helpText: "Username must be 3-30 characters"
            )

            FormTextField(
                label: "Invalid Field",
                text: .constant("bad input"),
                icon: "exclamationmark.triangle.fill",
                validationMessage: "This field contains invalid characters"
            )

            FormSecureField(
                label: "Password",
                text: .constant(""),
                placeholder: "Enter password",
                isRequired: true
            )
        }
        .padding()
    }
}
