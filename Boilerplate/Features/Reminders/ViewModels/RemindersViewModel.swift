import Foundation

@Observable
final class RemindersViewModel {
    let uid: String
    private let onboarding: OnboardingService

    var rows: [OnboardingService.Reminder] = []
    var isLoading = false
    var isDeleting = false
    var errorMessage: String?

    var isSelecting = false
    var selectedIds: Set<String> = []

    var page: Int = 1
    let pageSize: Int = 25

    init(uid: String, onboarding: OnboardingService) {
        self.uid = uid
        self.onboarding = onboarding
    }

    var visibleRows: [OnboardingService.Reminder] {
        // Web parity: only show items that are not reminded yet.
        rows.filter { !$0.isReminded }
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(visibleRows.count) / Double(pageSize))))
    }

    var pagedRows: [OnboardingService.Reminder] {
        let start = max(0, (page - 1) * pageSize)
        let end = min(visibleRows.count, start + pageSize)
        if start >= end { return [] }
        return Array(visibleRows[start..<end])
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await onboarding.listReminders(uid: uid)
            // Web uses query(orderBy date asc) and then filters `!isReminded`.
            rows = data
            selectedIds.removeAll()
            isSelecting = false
            page = min(page, totalPages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func createReminder(title: String, description: String, date: String, isReminded: Bool) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return }
        do {
            _ = try await onboarding.createReminder(
                uid: uid,
                title: trimmedTitle,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                isReminded: isReminded
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func bulkDeleteSelected() async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await onboarding.deleteReminders(uid: uid, ids: ids)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateReminder(reminderId: String, title: String, description: String, date: String) async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        do {
            try await onboarding.updateReminder(
                uid: uid,
                reminderId: reminderId,
                title: t,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

