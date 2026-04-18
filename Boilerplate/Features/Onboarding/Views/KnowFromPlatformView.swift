import SwiftUI

struct KnowFromPlatformView: View {
    let onboarding: OnboardingService
    let uid: String
    let onSelected: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSaving = false
    @State private var showCards = false
    @State private var selectedOption: String?
    @State private var pressedOption: String?

    private let options = ["Google", "Friends/Family", "Social Media"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, name in
                            optionCard(
                                title: name,
                                isSelected: selectedOption == name,
                                isPressed: pressedOption == name
                            ) {
                                select(name)
                            }
                            .disabled(isSaving)
                            .opacity(showCards ? 1 : 0)
                            .offset(y: showCards ? 0 : -10)
                            .animation(.easeOut(duration: 0.22).delay(0.08 * Double(index)), value: showCards)
                        }
                    }
                    .padding(.top, proxy.size.height * 0.20)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 0)

                    promptOverlay(containerSize: proxy.size)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .onAppear { showCards = true }
        }
    }

    private func select(_ name: String) {
        guard !isSaving else { return }

        selectedOption = name
        pressedOption = name
        isSaving = true

        Task { @MainActor in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                pressedOption = name
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                pressedOption = nil
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            onSelected(name)
        }

        // Background persistence (web parity: do not block UI / routing).
        Task.detached(priority: .utility) {
            do { try await onboarding.updateUserProfile(uid: uid, fields: ["platform": name]) } catch {}
        }
    }
}

// MARK: - UI (web parity)

private extension KnowFromPlatformView {
    func promptOverlay(containerSize: CGSize) -> some View {
        let isCompact = containerSize.width < 430
        let avatarSize: CGFloat = isCompact ? 176 : 216

        return VStack(spacing: 10) {
            speechBubble(text: "Where did you hear about Budge?", availableWidth: containerSize.width)

            Image("knowAbout")
                .resizable()
                .scaledToFit()
                .frame(width: avatarSize, height: avatarSize)
        }
    }

    func speechBubble(text: String, availableWidth: CGFloat) -> some View {
        let maxBubbleWidth = min(availableWidth - (UIConstants.Padding.section * 2), 360)

        return ZStack(alignment: .bottom) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(width: maxBubbleWidth)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.budgeAuthCard)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.Colors.budgeAuthBorder, lineWidth: 1)
                )

            speechTail
                .offset(y: 8)
        }
    }

    var speechTail: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.Colors.budgeAuthCard)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
            Rectangle()
                .strokeBorder(AppTheme.Colors.budgeAuthBorder, lineWidth: 1)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 22, height: 11)
        .clipped()
    }

    func optionCard(title: String, isSelected: Bool, isPressed: Bool, action: @escaping () -> Void) -> some View {
        let cardWidth: CGFloat = horizontalSizeClass == .regular ? 368 : 288 // 23rem / 18rem
        let verticalPadding: CGFloat = horizontalSizeClass == .regular ? 32 : 16 // py 8 / 4

        let borderColor = isSelected ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.budgeAuthBorder
        let borderWidth: CGFloat = isSelected ? 2 : 1
        let scale: CGFloat = isPressed ? 0.97 : 1.0

        return Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                .frame(width: cardWidth)
                .padding(.horizontal, 40) // px 10
                .padding(.vertical, verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.budgeAuthCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .opacity(isSaving ? 0.75 : 1)
                .scaleEffect(scale)
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isPressed)
                .shimmer(when: isSaving, duration: 1.0, bounce: false)
        }
        .buttonStyle(.plain)
    }
}
