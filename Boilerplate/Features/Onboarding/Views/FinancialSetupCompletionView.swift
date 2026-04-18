import SwiftUI

/// Mirrors React `/financial-setup/completion` → short celebration before expense.
struct FinancialSetupCompletionView: View {
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var didFire = false
    @State private var imageLoaded = false
    @State private var didAppear = false

    private var pageBackground: Color {
        colorScheme == .dark ? Color(hex: "#1D1D1F") : AppTheme.Colors.budgeAuthBackground
    }

    private var pageTextPrimary: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6") : AppTheme.Colors.budgeAuthTextPrimary
    }

    private var pageTextSecondary: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6") : AppTheme.Colors.budgeAuthTextSecondary
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                ZStack {
                    if !imageLoaded {
                        ProgressView()
                            .tint(AppTheme.Colors.budgeGreenPrimary)
                            .scaleEffect(1.2)
                    }

                    Image("Drum")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 192, height: 192)
                        .opacity(imageLoaded ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: imageLoaded)
                        .onAppear { imageLoaded = true }
                }

                Text("You Are So Fast!! 😎")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(pageTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Text("I knew that you are amazing")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(pageTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, UIConstants.Padding.section)
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 80)
            .animation(.easeInOut(duration: 0.6), value: didAppear)
        }
        .onAppear {
            guard !didFire else { return }
            didFire = true
            didAppear = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onContinue()
            }
        }
    }
}
