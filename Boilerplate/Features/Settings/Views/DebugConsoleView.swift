import SwiftUI

struct DebugConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LogEntry] = []
    @State private var filterCategory: String? = nil
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true

    private let categories = ["App", "Network", "Data", "UI", "Auth"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredEntries) { entry in
                            logRow(entry)
                                .id(entry.id)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                    }
                    .listStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: entries.count) {
                        if autoScroll, let last = filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                statusBar
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            let text = filteredEntries.map(\.formatted).joined(separator: "\n")
                            UIPasteboard.general.string = text
                        } label: {
                            Label("Copy Logs", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            LogBuffer.shared.clear()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        Toggle("Auto-scroll", isOn: $autoScroll)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Filter logs...")
            .onAppear { entries = LogBuffer.shared.getEntries() }
            .task {
                LogBuffer.shared.onChange = {
                    entries = LogBuffer.shared.getEntries()
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    FilterChip(label: cat, isActive: filterCategory == cat) {
                        filterCategory = filterCategory == cat ? nil : cat
                    }
                }
                Divider().frame(height: 20)
                ForEach([LogLevel.error, .warning, .info, .debug], id: \.rawValue) { level in
                    FilterChip(label: level.label, color: level.color, isActive: filterLevel == level) {
                        filterLevel = filterLevel == level ? nil : level
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.levelIcon)
                .fontWeight(.bold)
                .foregroundStyle(entry.level.color)
                .frame(width: 14)
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .foregroundStyle(.secondary)
            Text(entry.category)
                .foregroundStyle(.blue)
                .frame(width: 48, alignment: .leading)
            Text(entry.message)
                .foregroundStyle(.primary)
                .lineLimit(5)
        }
    }

    private var statusBar: some View {
        HStack {
            Text("\(filteredEntries.count) / \(entries.count) entries")
            Spacer()
            Text(AppEnvironment.isTestFlight ? "TestFlight" : "Debug")
                .foregroundStyle(AppEnvironment.isTestFlight ? .orange : .green)
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private var filteredEntries: [LogEntry] {
        entries.filter { entry in
            if let cat = filterCategory, entry.category != cat { return false }
            if let level = filterLevel, entry.level != level { return false }
            if !searchText.isEmpty, !entry.message.localizedCaseInsensitiveContains(searchText) { return false }
            return true
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

private struct FilterChip: View {
    let label: String
    var color: Color = .primary
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? color.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isActive ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isActive ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
    }
}

extension LogLevel {
    var label: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warn"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }
}
