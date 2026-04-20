import SwiftUI

struct RemindersView: View {
    @Environment(OnboardingService.self) private var onboarding
    @Environment(AuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: RemindersViewModel?
    @State private var showCreate = false
    @State private var showDeleteConfirm = false
    @State private var editingReminder: OnboardingService.Reminder?

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView()
                        .tint(palette.brandGreenPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.screenBackground)
                }
            }

            if (viewModel?.isDeleting ?? false) {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                ProgressView("Deleting…")
                    .tint(palette.brandGreenPrimary)
                    .padding(16)
                    .background(palette.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .background(palette.screenBackground)
        .navigationTitle("My Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil, let uid = authService.currentUser?.id {
                let vm = RemindersViewModel(uid: uid, onboarding: onboarding)
                viewModel = vm
                await vm.load()
            }
        }
        .sheet(isPresented: $showCreate) {
            if let vm = viewModel {
                CreateReminderSheet(palette: palette, viewModel: vm) {
                    showCreate = false
                }
            }
        }
        .sheet(item: $editingReminder) { r in
            if let vm = viewModel {
                EditReminderSheet(palette: palette, viewModel: vm, reminder: r) {
                    editingReminder = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel?.errorMessage = nil }
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete selected reminders?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { @MainActor in
                    await viewModel?.bulkDeleteSelected()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func content(_ vm: RemindersViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if vm.isLoading, vm.rows.isEmpty {
                    ProgressView()
                        .tint(palette.brandGreenPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if !vm.isLoading, vm.visibleRows.isEmpty {
                    Text("No reminders set yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.bodyText.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                }

                ForEach(vm.pagedRows, id: \.id) { r in
                    reminderCard(vm: vm, row: r)
                }

                paginationControls(vm: vm)
            }
            .padding(16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap outside any reminder card exits selection mode ("Done Selecting").
            if vm.isSelecting {
                vm.isSelecting = false
                vm.selectedIds.removeAll()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Create reminder", systemImage: "plus.circle")
                    }

                    if vm.isSelecting {
                        Button(role: .destructive) {
                            if !vm.selectedIds.isEmpty {
                                showDeleteConfirm = true
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(vm.selectedIds.isEmpty)

                        Button {
                            vm.isSelecting = false
                            vm.selectedIds.removeAll()
                        } label: {
                            Label("Done selecting", systemImage: "checkmark.circle")
                        }
                    } else {
                        Button {
                            vm.isSelecting = true
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        .disabled(vm.visibleRows.isEmpty)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(palette.bodyText)
                }
            }
        }
    }

    @ViewBuilder
    private func reminderCard(vm: RemindersViewModel, row: OnboardingService.Reminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if vm.isSelecting {
                Image(systemName: vm.selectedIds.contains(row.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(vm.selectedIds.contains(row.id) ? palette.brandGreenPrimary : palette.bodyText.opacity(0.35))
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(row.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.bodyText)
                    .lineLimit(2)

                if !row.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(row.description)
                        .font(.subheadline)
                        .foregroundStyle(palette.bodyText.opacity(0.75))
                        .lineLimit(3)
                }

                HStack {
                    Text(Self.formatDateTime(row.date))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.bodyText.opacity(0.65))
                    Spacer()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(palette.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                if vm.isSelecting {
                    toggleSelection(vm: vm, id: row.id)
                } else {
                    editingReminder = row
                }
            }
        )
        .contextMenu {
            Button("Select") {
                vm.isSelecting = true
                vm.selectedIds = [row.id]
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            // Long-press should immediately enter selection mode and select the pressed row.
            if !vm.isSelecting {
                vm.isSelecting = true
                vm.selectedIds = [row.id]
            } else {
                toggleSelection(vm: vm, id: row.id)
            }
        }
    }

    private func toggleSelection(vm: RemindersViewModel, id: String) {
        if vm.selectedIds.contains(id) {
            vm.selectedIds.remove(id)
        } else {
            vm.selectedIds.insert(id)
        }
    }

    @ViewBuilder
    private func paginationControls(vm: RemindersViewModel) -> some View {
        if vm.visibleRows.count > 0 {
            HStack {
                Text("Page \(vm.page) of \(vm.totalPages)")
                    .font(.footnote)
                    .foregroundStyle(palette.bodyText.opacity(0.75))
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        vm.page = max(1, vm.page - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.bodyText)
                            .padding(10)
                            .background(palette.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(vm.page <= 1)

                    Button {
                        vm.page = min(vm.totalPages, vm.page + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.bodyText)
                            .padding(10)
                            .background(palette.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(vm.page >= vm.totalPages)
                }
            }
            .padding(.top, 4)
        }
    }

    /// Web parity: timezone-independent parse of `YYYY-MM-DDTHH:mm:ss` (no Z) and legacy `YYYY-MM-DD` (default 09:00).
    static func formatDateTime(_ dateTimeString: String) -> String {
        let s = dateTimeString.trimmingCharacters(in: .whitespacesAndNewlines)

        func makeDate(y: Int, m: Int, d: Int, hh: Int, mm: Int, ss: Int) -> Date? {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "en_US_POSIX")
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = d
            comps.hour = hh
            comps.minute = mm
            comps.second = ss
            return cal.date(from: comps)
        }

        if let m = s.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/) {
            let y = Int(m.1) ?? 0
            let mo = Int(m.2) ?? 1
            let d = Int(m.3) ?? 1
            let hh = Int(m.4) ?? 0
            let mm = Int(m.5) ?? 0
            let ss = Int(m.6) ?? 0
            if let date = makeDate(y: y, m: mo, d: d, hh: hh, mm: mm, ss: ss) {
                return date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
            }
            return s
        }

        if let m = s.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/) {
            let y = Int(m.1) ?? 0
            let mo = Int(m.2) ?? 1
            let d = Int(m.3) ?? 1
            if let date = makeDate(y: y, m: mo, d: d, hh: 9, mm: 0, ss: 0) {
                return date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
            }
            return s
        }

        return s
    }
}

// MARK: - Create reminder sheet (mobile web modal parity)

private struct CreateReminderSheet: View {
    let palette: BudgeChatPalette
    let viewModel: RemindersViewModel
    let onClose: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var time = Date()
    @State private var isReminded = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description (optional)", text: $description)

                DatePicker("Date", selection: $date, displayedComponents: [.date])
                DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute])

                Toggle("Already Reminded", isOn: $isReminded)
            }
            .navigationTitle("Create Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(palette.brandGreenPrimary)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let dateString = Self.makeDateTimeString(date: date, time: time)
        await viewModel.createReminder(title: title, description: description, date: dateString, isReminded: isReminded)
        onClose()
    }

    /// Web parity: build `YYYY-MM-DDTHH:mm:ss` string (no timezone suffix).
    fileprivate static func makeDateTimeString(date: Date, time: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        let y = day.year ?? 1970
        let m = day.month ?? 1
        let d = day.day ?? 1
        let hh = t.hour ?? 9
        let mm = t.minute ?? 0
        return String(format: "%04d-%02d-%02dT%02d:%02d:00", y, m, d, hh, mm)
    }
}

// MARK: - Edit reminder sheet ("slider")

private struct EditReminderSheet: View {
    let palette: BudgeChatPalette
    let viewModel: RemindersViewModel
    let reminder: OnboardingService.Reminder
    let onClose: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var date: Date
    @State private var time: Date
    @State private var isSaving = false

    init(palette: BudgeChatPalette, viewModel: RemindersViewModel, reminder: OnboardingService.Reminder, onClose: @escaping () -> Void) {
        self.palette = palette
        self.viewModel = viewModel
        self.reminder = reminder
        self.onClose = onClose
        _title = State(initialValue: reminder.title)
        _description = State(initialValue: reminder.description)
        let fallbackDay = Calendar(identifier: .gregorian).startOfDay(for: Date())
        let fallbackTime = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 9, minute: 0)) ?? Date()
        let parsed = Self.parseDateTime(reminder.date) ?? (fallbackDay, fallbackTime)
        _date = State(initialValue: parsed.date)
        _time = State(initialValue: parsed.time)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description (optional)", text: $description)
                DatePicker("Date", selection: $date, displayedComponents: [.date])
                DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute])
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(palette.brandGreenPrimary)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let dateString = CreateReminderSheet.makeDateTimeString(date: date, time: time)
        await viewModel.updateReminder(reminderId: reminder.id, title: title, description: description, date: dateString)
        onClose()
    }

    private static func parseDateTime(_ s: String) -> (date: Date, time: Date)? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")

        func build(y: Int, m: Int, d: Int, hh: Int, mm: Int, ss: Int) -> Date? {
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = d
            comps.hour = hh
            comps.minute = mm
            comps.second = ss
            return cal.date(from: comps)
        }

        if let m = trimmed.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/) {
            let y = Int(m.1) ?? 1970
            let mo = Int(m.2) ?? 1
            let d = Int(m.3) ?? 1
            let hh = Int(m.4) ?? 9
            let mm = Int(m.5) ?? 0
            let ss = Int(m.6) ?? 0
            guard let dt = build(y: y, m: mo, d: d, hh: hh, mm: mm, ss: ss) else { return nil }
            // Split into date-only + time-only for pickers.
            let dayOnly = cal.startOfDay(for: dt)
            let timeOnly = build(y: 2000, m: 1, d: 1, hh: hh, mm: mm, ss: 0) ?? Date()
            return (dayOnly, timeOnly)
        }

        if let m = trimmed.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/) {
            let y = Int(m.1) ?? 1970
            let mo = Int(m.2) ?? 1
            let d = Int(m.3) ?? 1
            guard let dayOnly = build(y: y, m: mo, d: d, hh: 0, mm: 0, ss: 0) else { return nil }
            let timeOnly = build(y: 2000, m: 1, d: 1, hh: 9, mm: 0, ss: 0) ?? Date()
            return (dayOnly, timeOnly)
        }

        return nil
    }
}

