import SwiftUI

struct Toast: View {
    enum Kind {
        case success
        case error
        case info
    }

    let kind: Kind
    let message: String

    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppTheme.Colors.budgeAuthCard)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                .stroke(AppTheme.Colors.budgeAuthBorder, lineWidth: UIConstants.Border.standard)
        )
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .padding(.horizontal, UIConstants.Padding.section)
    }

    private var iconName: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }
}

extension View {
    func toastOverlay(kind: Toast.Kind, message: String?, isPresented: Binding<Bool>, autoDismissAfter seconds: Double = 3.0) -> some View {
        overlay(alignment: .top) {
            if isPresented.wrappedValue, let message, !message.isEmpty {
                Toast(kind: kind, message: message)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
            }
        }
    }
}

