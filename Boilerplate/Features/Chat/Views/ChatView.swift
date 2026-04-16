import SwiftUI

struct ChatView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        VStack(spacing: 12) {
            Text("Chat")
                .font(.title2.weight(.semibold))
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") {
                    Task { await authService.signOut() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}

