import SwiftUI

struct JourneyCompletionView: View {
    let onEnterChat: () -> Void

    @State private var didFire = false
    @State private var imageLoaded = false
    @State private var didAppear = false

    var body: some View {
        ZStack {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                ZStack {
                    if !imageLoaded {
                        ProgressView()
                            .tint(AppTheme.Colors.budgeGreenPrimary)
                            .scaleEffect(1.2)
                    }

                    Image("charecterDark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 192, height: 192)
                        .opacity(imageLoaded ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: imageLoaded)
                        .onAppear { imageLoaded = true }
                }

                Text("Congratulation!!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                    .multilineTextAlignment(.center)

                Text("You are entering the Budge System")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.budgeAuthTextSecondary)
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
                onEnterChat()
            }
        }
    }
}
