import SwiftUI

struct UserTypeView: View {
    let onboarding: OnboardingService
    let uid: String
    let onSelected: (OnboardingUserType) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSaving = false
    @State private var showCards = false
    @State private var selectedType: OnboardingUserType?
    @State private var pressedType: OnboardingUserType?

    private let choices: [OnboardingUserType] = [.jobHolder, .entrepreneur, .student]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                            userTypeCard(
                                title: choice.rawValue,
                                isSelected: selectedType == choice,
                                isPressed: pressedType == choice
                            ) {
                                select(choice)
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

                    // Decorative prompt (bubble + mascot) pinned to bottom
                    promptOverlay(containerSize: proxy.size)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .onAppear {
                showCards = true
            }
        }
    }

    private func select(_ userType: OnboardingUserType) {
        guard !isSaving else { return }

        // Immediate UI feedback + instant routing (no gate loading flash).
        selectedType = userType
        pressedType = userType
        isSaving = true
        Task { @MainActor in
            // Give the user a moment to feel the press + see the selected (green) border before routing.
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                pressedType = userType
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                pressedType = nil
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            onSelected(userType)
        }

        // Background persistence (web parity: do not block UI / routing).
        Task.detached(priority: .utility) {
            // 1) Best-effort persist userType.
            do { try await onboarding.updateUserProfile(uid: uid, fields: ["userType": userType.rawValue]) } catch {}

            // 2) Best-effort conditional seeding; only if nothing exists yet.
            do {
                let (inc, exp) = try await onboarding.fetchFinancialCategoriesCount(uid: uid)
                if inc == 0, exp == 0 {
                    try await onboarding.seedFinancialCategoryDocuments(uid: uid, userType: userType)
                }
            } catch {}
        }
    }
}

// MARK: - UI (web parity)

private extension UserTypeView {
    func promptOverlay(containerSize: CGSize) -> some View {
        let isCompact = containerSize.width < 430
        let avatarSize: CGFloat = isCompact ? 176 : 216

        return VStack(spacing: 10) {
            speechBubble(text: "Which best describes you?", availableWidth: containerSize.width)

            Image("whyUseImage")
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
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(width: maxBubbleWidth)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.budgeAuthCard)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(hex: "#D2D2D7"), lineWidth: 1)
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
                .strokeBorder(Color(hex: "#D2D2D7"), lineWidth: 1)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 22, height: 11)
        .clipped()
    }

    func userTypeCard(title: String, isSelected: Bool, isPressed: Bool, action: @escaping () -> Void) -> some View {
        let cardWidth: CGFloat = horizontalSizeClass == .regular ? 368 : 288 // 23rem / 18rem
        let verticalPadding: CGFloat = horizontalSizeClass == .regular ? 32 : 16 // py 8 / 4

        let borderColor = isSelected ? AppTheme.Colors.budgeGreenPrimary : Color(hex: "#D2D2D7")
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
