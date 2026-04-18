import SwiftUI
import UIKit

/// Loads `photoURL` when present; otherwise shows initials on a tinted circle (matches web `photoURL` usage).
/// Pass `cachedImage` when `AuthService` has already loaded the avatar from disk or memory (avoids repeated network fetches).
struct ProfileAvatarCircle: View {
    let name: String?
    let photoURL: URL?
    var cachedImage: UIImage? = nil
    var size: CGFloat = 34
    var placeholderFill: Color = Color.secondary.opacity(0.35)
    var textColor: Color = .primary

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack {
                            placeholder
                            ProgressView()
                                .scaleEffect(0.65)
                        }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())

    }

    private var placeholder: some View {
        Circle()
            .fill(placeholderFill)
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: max(10, size * 0.32), weight: .bold))
                    .foregroundStyle(textColor.opacity(0.85))
            )
    }

    private func initials(from name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if parts.isEmpty { return "U" }
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        return String(first + last).uppercased()
    }
}
