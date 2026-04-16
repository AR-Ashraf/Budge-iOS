import SwiftUI

/// Mirrors `initialization-completion` → short celebration before financial setup.
struct InitializationCompletionView: View {
    let onContinue: () -> Void

    @State private var didFire = false
    @State private var imageVisible = false
    @State private var containerOffsetY: CGFloat = 80
    @State private var containerOpacity: Double = 0

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                ZStack {
                    if !imageVisible {
                        ProgressView()
                            .tint(AppTheme.Colors.budgeGreenPrimary)
                            .scaleEffect(1.2)
                    }

                    Image("congratulation")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 192, height: 192)
                        .opacity(imageVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: imageVisible)
                        .onAppear { imageVisible = true }
                }

                Text(" Congratulations!!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("You have done a great jobs.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, UIConstants.Padding.section)
            .offset(y: containerOffsetY)
            .opacity(containerOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6)) {
                    containerOffsetY = 0
                    containerOpacity = 1
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.budgeAuthBackground.ignoresSafeArea())
        .onAppear {
            guard !didFire else { return }
            didFire = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onContinue()
            }
        }
    }
}
