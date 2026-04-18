import SwiftUI

/// Budge wordmark for auth screens: `Brand` (light) / `brandDark` (dark) in Assets.
struct AuthBrandLogo: View {
    /// Baseline height (light). Dark uses a smaller scale so `brandDark` doesn’t dominate the header.
    var height: CGFloat = 120

    @Environment(\.colorScheme) private var colorScheme

    private var resolvedHeight: CGFloat {
        if colorScheme == .dark {
            return height * 0.50
        }
        return height
    }

    var body: some View {
        Image(colorScheme == .dark ? "brandDark" : "Brand")
            .resizable()
            .scaledToFit()
            .frame(height: resolvedHeight)
    }
}
