import SwiftUI

struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .center) {
            Color.white.ignoresSafeArea()

            Image("charecterDark")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220, alignment: .center)
                .opacity(isVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            withAnimation(.easeIn(duration: 0.45)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashView()
}

