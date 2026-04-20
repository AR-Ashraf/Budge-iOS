import SwiftUI
import UIKit

private enum ChatHistorySectioning {
    static func groupThreadsByDateSection(_ threads: [ChatService.ChatThread]) -> [String: [ChatService.ChatThread]] {
        let now = Date()
        let cal = Calendar.current

        let startOfToday = cal.startOfDay(for: now)
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOf7DaysAgo = cal.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        let startOf14DaysAgo = cal.date(byAdding: .day, value: -14, to: startOfToday) ?? startOfToday
        let startOf30DaysAgo = cal.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday

        var sections: [String: [ChatService.ChatThread]] = [:]

        for t in threads {
            guard let ts = t.timestamp else { continue }
            let section: String
            if ts >= startOfToday {
                section = "Today"
            } else if ts >= startOfYesterday {
                section = "Yesterday"
            } else if ts >= startOf7DaysAgo {
                section = "Previous 7 Days"
            } else if ts >= startOf14DaysAgo {
                section = "Previous 14 Days"
            } else if ts >= startOf30DaysAgo {
                section = "Previous 30 Days"
            } else {
                section = ts.formatted(.dateTime.month(.wide).year())
            }

            sections[section, default: []].append(t)
        }

        for key in sections.keys {
            sections[key]?.sort { (a, b) in
                (a.timestamp ?? .distantPast) > (b.timestamp ?? .distantPast)
            }
        }

        return sections
    }

    static func orderedSectionKeys(_ sections: [String: [ChatService.ChatThread]]) -> [String] {
        let present = Set(sections.keys)
        let priority = ["Today", "Yesterday", "Previous 7 Days", "Previous 14 Days", "Previous 30 Days"].filter { present.contains($0) }

        let monthKeys = sections.keys
            .filter { !priority.contains($0) }
            .sorted { a, b in
                parseMonthKey(b) > parseMonthKey(a)
            }

        return priority + monthKeys
    }

    private static func parseMonthKey(_ s: String) -> TimeInterval {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        if let d = f.date(from: s) { return d.timeIntervalSince1970 }
        if let d = ISO8601DateFormatter().date(from: s) { return d.timeIntervalSince1970 }
        return 0
    }
}

struct ChatSidebarDrawer: View {
    @Binding var visible: Bool
    @Bindable var model: ChatViewModel
    let onDismissKeyboard: () -> Void
    /// Opens the Balance Sheet (chart) — React `/chart` parity.
    var onBalanceSheet: () -> Void = {}

    @Environment(AuthService.self) private var authService
    @Environment(ThemeController.self) private var themeController
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchQuery: String = ""
    @State private var pendingRenameThread: ChatService.ChatThread?
    @State private var renameValue: String = ""
    @State private var pendingDeleteThread: ChatService.ChatThread?
    @State private var showProfileSheet: Bool = false
    @State private var showProfileComingSoon: Bool = false
    @State private var presented: Bool = false
    @State private var drawerOffsetX: CGFloat = 0

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    private var drawerWidth: CGFloat { UIScreen.main.bounds.width }

    private var filteredThreads: [ChatService.ChatThread] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return model.chatThreads }
        let lower = q.lowercased()
        return model.chatThreads.filter { $0.title.lowercased().contains(lower) }
    }

    var body: some View {
        if visible {
            let offset = max(-drawerWidth, min(0, drawerOffsetX))
            let dimOpacity = 0.45 * (1.0 - min(1.0, abs(offset) / max(1.0, drawerWidth)))

            ZStack(alignment: .leading) {
                Color.black.opacity(dimOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                drawer
                    .frame(width: drawerWidth)
                    .offset(x: offset)
                    .animation(.easeInOut(duration: 0.28), value: presented)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15), value: drawerOffsetX)
                    .gesture(dragToDismissGesture)
            }
            .onAppear {
                onDismissKeyboard()
                withAnimation(.easeInOut(duration: 0.28)) {
                    presented = true
                    drawerOffsetX = 0
                }
                Task { await model.refreshChatThreads() }
            }
            .onDisappear {
                presented = false
                drawerOffsetX = 0
            }
            .alert("Rename chat", isPresented: Binding(get: { pendingRenameThread != nil }, set: { if !$0 { pendingRenameThread = nil } })) {
                TextField("Title", text: $renameValue)
                Button("Cancel", role: .cancel) { pendingRenameThread = nil }
                Button("Save") {
                    Task { await commitRename() }
                }
            }
            .confirmationDialog(
                "Delete this chat?",
                isPresented: Binding(get: { pendingDeleteThread != nil }, set: { if !$0 { pendingDeleteThread = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await commitDelete() }
                }
                Button("Cancel", role: .cancel) { pendingDeleteThread = nil }
            }
        }
    }

    private var drawer: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom

            VStack(alignment: .leading, spacing: 14) {
                headerRow
                    .padding(.top, max(10, topInset) + 50)

                searchRow
                balanceSheetRow
                chatHistoryList
                Spacer(minLength: 0)
                profileRow
                    .padding(.bottom, max(12, bottomInset) + 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(palette.cardSurface)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            Button {
                model.beginNewChat()
                dismiss()
            } label: {
                Image(colorScheme == .dark ? "brandDark" : "BrandSidebarLight")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                    .frame(maxWidth: 150, alignment: .leading)
                    .clipped()
                    .accessibilityLabel("Budge")
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: toggleThemePreference) {
                Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(palette.inputInnerBackground)
                            .overlay(Circle().strokeBorder(palette.borderPrimary.opacity(0.6), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle theme")
        }
        .padding(.bottom, 4)
    }

    private var searchRow: some View {
        let placeholderColor = colorScheme == .dark
            ? palette.bodyText.opacity(0.55)
            : Color.black.opacity(0.55)

        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.55))

                TextField(
                    text: $searchQuery,
                    prompt: Text("Search").foregroundStyle(placeholderColor)
                ) {}
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(palette.bodyText)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(palette.inputInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
            )

            Button {
                model.beginNewChat()
                dismiss()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background(palette.inputInnerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New chat")
        }
    }

    private var balanceSheetRow: some View {
        Button {
            onBalanceSheet()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image("excelIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Balance Sheet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : palette.brandGreenDarkText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(palette.brandGreenPrimary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Balance Sheet")
    }

    private var chatHistoryList: some View {
        let threads = filteredThreads
        let sections = ChatHistorySectioning.groupThreadsByDateSection(threads)
        let keys = ChatHistorySectioning.orderedSectionKeys(sections)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.chatThreadsLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(palette.brandGreenPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }

                if !model.chatThreadsLoading, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, threads.isEmpty {
                    HStack {
                        Spacer()
                        Text("No Result Found")
                            .font(.subheadline)
                            .foregroundStyle(palette.bodyText.opacity(0.6))
                        Spacer()
                    }
                    .padding(.vertical, 18)
                }

                ForEach(keys, id: \.self) { section in
                    if let items = sections[section], !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.blue.opacity(0.95))

                            VStack(spacing: 6) {
                                ForEach(items) { t in
                                    threadRow(t)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func threadRow(_ t: ChatService.ChatThread) -> some View {
        let isCurrent = t.id == model.chatId

        // Not using `Button` here: with `Spacer()`, long-press for `contextMenu` often only hit-tests the
        // text. `onTapGesture` + `contextMenu` on one shaped row fixes full-row long press.
        return HStack(spacing: 10) {
            Text(t.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.bodyText.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .contentShape(Rectangle())
        .background(isCurrent ? palette.inputInnerBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            model.openChat(chatId: t.id)
            dismiss()
        }
        .contextMenu {
            Button("Rename") {
                pendingRenameThread = t
                renameValue = t.title
            }
            Button("Delete", role: .destructive) {
                pendingDeleteThread = t
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var profileRow: some View {
        Button {
            showProfileSheet = true
        } label: {
            HStack(spacing: 12) {
                ProfileAvatarCircle(
                    name: authService.currentUser?.name,
                    photoURL: authService.currentUser?.avatarURL,
                    cachedImage: authService.cachedProfilePhoto,
                    size: 34,
                    placeholderFill: palette.borderPrimary.opacity(0.35),
                    textColor: palette.bodyText
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(authService.currentUser?.name ?? "Profile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.bodyText)
                        .lineLimit(1)
                    Text(authService.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundStyle(palette.bodyText.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.inputInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showProfileSheet) {
            ProfileSettingsSheet(
                palette: palette,
                userName: authService.currentUser?.name ?? "Profile",
                userEmail: authService.currentUser?.email ?? "",
                onLogout: {
                    Task { @MainActor in
                        await authService.signOut()
                        showProfileSheet = false
                        dismiss()
                    }
                },
                onOpenReminders: {
                    showProfileComingSoon = true
                }
            )
        }
        .alert("Coming soon", isPresented: $showProfileComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This feature will be available in a future update.")
        }
    }

    private var dragToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                // Only allow dragging left to close.
                drawerOffsetX = min(0, value.translation.width)
            }
            .onEnded { value in
                let closeThreshold = drawerWidth * 0.22
                let predicted = value.predictedEndTranslation.width
                if value.translation.width < -closeThreshold || predicted < -closeThreshold {
                    dismiss()
                } else {
                    // Snap back open.
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                        presented = true
                        drawerOffsetX = 0
                    }
                }
            }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            presented = false
            drawerOffsetX = -drawerWidth
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            visible = false
            drawerOffsetX = 0
        }
    }

    private func initials(from name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if parts.isEmpty { return "U" }
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        return String(first + last).uppercased()
    }

    private func toggleThemePreference() {
        themeController.toggleLightDark(currentSystemScheme: colorScheme)
    }

    @MainActor
    private func commitRename() async {
        guard let t = pendingRenameThread else { return }
        defer { pendingRenameThread = nil }
        let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await model.renameChatThread(chatId: t.id, newTitle: trimmed)
    }

    @MainActor
    private func commitDelete() async {
        guard let t = pendingDeleteThread else { return }
        defer { pendingDeleteThread = nil }
        await model.deleteChatThread(chatId: t.id)
    }
}

// MARK: - Profile photo library (UIImagePickerController)

private struct ProfilePhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var pickedImage: UIImage?
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfilePhotoLibraryPicker

        init(_ parent: ProfilePhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.pickedImage = img
            parent.onDismiss()
        }
    }
}

// MARK: - Profile settings sheet (Apple-style)

private struct ProfileSettingsSheet: View {
    let palette: BudgeChatPalette
    let userName: String
    let userEmail: String
    let onLogout: () -> Void
    let onOpenReminders: () -> Void

    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var showPhotoLibraryPicker = false
    @State private var pickedUIImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var uploadErrorMessage: String?

    var body: some View {
        NavigationStack {
            profileSettingsList
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var profileSettingsList: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button {
                        showPhotoLibraryPicker = true
                    } label: {
                        ZStack {
                            ProfileAvatarCircle(
                                name: userName,
                                photoURL: authService.currentUser?.avatarURL,
                                cachedImage: authService.cachedProfilePhoto,
                                size: 44,
                                placeholderFill: palette.borderPrimary.opacity(0.35),
                                textColor: palette.bodyText
                            )
                            if isUploadingPhoto {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 44, height: 44)
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .accessibilityLabel("Change profile photo")
                        .accessibilityHint("Opens your photo library")
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploadingPhoto)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.bodyText)
                            .lineLimit(1)
                        if !userEmail.isEmpty {
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundStyle(palette.bodyText.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(palette.cardSurface)

            Section {
                NavigationLink {
                    HelpMenuView(palette: palette)
                } label: {
                    settingsRow(
                        title: "Help",
                        systemImage: "questionmark.circle",
                        showChevron: false
                    )
                }

                NavigationLink {
                    RemindersView()
                } label: {
                    // `NavigationLink` already renders a disclosure indicator in a `List`.
                    settingsRow(title: "My Reminders", systemImage: "bell", showChevron: false)
                }

                NavigationLink {
                    AccountsView(focusAccountId: nil)
                } label: {
                    // `NavigationLink` already renders a disclosure indicator in a `List`.
                    settingsRow(title: "My Accounts", systemImage: "creditcard", showChevron: false)
                }
            }
            .listRowBackground(palette.cardSurface)

            Section {
                Button(role: .destructive) {
                    onLogout()
                } label: {
                    settingsRow(title: "Logout", systemImage: "rectangle.portrait.and.arrow.right", showChevron: false, destructive: true)
                }
            }
            .listRowBackground(palette.cardSurface)

            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(palette.bodyText.opacity(0.7))
                    Spacer()
                    Text(appVersionString())
                        .foregroundStyle(palette.bodyText.opacity(0.55))
                }
                .font(.footnote)
            }
            .listRowBackground(palette.cardSurface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.screenBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(palette.brandGreenPrimary)
            }
        }
        .alert("Couldn’t update photo", isPresented: Binding(
            get: { uploadErrorMessage != nil },
            set: { if !$0 { uploadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { uploadErrorMessage = nil }
        } message: {
            Text(uploadErrorMessage ?? "")
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ProfilePhotoLibraryPicker(pickedImage: $pickedUIImage) {
                showPhotoLibraryPicker = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedUIImage) { _, image in
            Task { await uploadPickedUIImage(image) }
        }
    }

    @MainActor
    private func uploadPickedUIImage(_ image: UIImage?) async {
        guard let image else { return }
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            pickedUIImage = nil
        }
        do {
            guard let jpeg = ProfilePhotoProcessing.jpegForUpload(image: image) else {
                uploadErrorMessage = "We couldn’t read that image. Try another photo."
                return
            }
            try await authService.uploadProfilePhoto(jpegData: jpeg)
        } catch {
            uploadErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func settingsRow(title: String, systemImage: String, showChevron: Bool, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : palette.bodyText.opacity(0.85))
                .frame(width: 22)
            Text(title)
                .foregroundStyle(destructive ? Color.red : palette.bodyText)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.45))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func appVersionString() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let v, let b { return "v\(v) (\(b))" }
        if let v { return "v\(v)" }
        return "v1.0.0"
    }
}

private struct HelpMenuView: View {
    let palette: BudgeChatPalette

    var body: some View {
        List {
            Section {
                helpLink("Help Center", slug: "help-center")
                helpLink("Release Notes", slug: "release-notes")
                helpLink("Privacy Policy", slug: "privacy-policy")
                helpLink("Terms & Conditions", slug: "terms-&-conditions")
                helpLink("Report Bug", slug: "report-bug")
                helpLink("Download App", slug: "download-app")
            }
            .listRowBackground(palette.cardSurface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.screenBackground)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpLink(_ title: String, slug: String) -> some View {
        Button {
            guard let url = URL(string: "https://mybudge.ai/\(slug)") else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(palette.bodyText)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.bodyText.opacity(0.45))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}


