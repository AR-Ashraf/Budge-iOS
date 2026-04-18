import SwiftUI

struct SplashView: View {
    var animate: Bool = true
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .center) {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            Image("charecterDark")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220, alignment: .center)
                .opacity(isVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            guard !isVisible else { return }
            if animate {
                withAnimation(.easeIn(duration: 0.45)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashView(animate: true)
}

