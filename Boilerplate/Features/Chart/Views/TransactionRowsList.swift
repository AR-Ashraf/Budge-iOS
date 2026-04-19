import SwiftUI
import UIKit

struct TransactionRowsList: View {
    let rows: [[String: Any]]
    let accounts: [OnboardingService.FinanceAccountSnapshot]
    let categoryName: (String) -> String
    @Binding var selected: Set<String>
    /// Draft note text by transaction id when different from `rows` (toolbar Save).
    @Binding var pendingNoteEdits: [String: String]

    let rowHighlightTint: Color
    let highlightedRowId: String?
    let onRowHighlight: (String) -> Void

    /// Must match header — full-column backgrounds; spacing 0 (web table has no inter-column gap).
    private let colWidths: [CGFloat] = [28, 120, 100, 100, 72, 72, 88, 120]

    private var rowSeparatorColor: Color { Color.primary.opacity(0.12) }

    private var hairlineHeight: CGFloat { 1.0 / max(UIScreen.main.scale, 2.0) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    transactionRow(row: row)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            txColumn(width: colWidths[0], columnIndex: 0, alignment: .center) {
                Image(systemName: "square")
                    .font(.caption2)
                    .opacity(0)
            }
            txColumn(width: colWidths[1], columnIndex: 1, alignment: .leading) {
                Text("Date").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[2], columnIndex: 2, alignment: .leading) {
                Text("Account").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[3], columnIndex: 3, alignment: .leading) {
                Text("Category").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[4], columnIndex: 4, alignment: .trailing) {
                Text("Pay").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[5], columnIndex: 5, alignment: .trailing) {
                Text("Dep").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[6], columnIndex: 6, alignment: .trailing) {
                Text("Bal").font(.caption2.weight(.bold))
            }
            txColumn(width: colWidths[7], columnIndex: 7, alignment: .leading) {
                Text("Note").font(.caption2.weight(.bold))
            }
        }
        .tableRowBottomSeparator(color: rowSeparatorColor, height: hairlineHeight)
    }

    private func transactionRow(row: [String: Any]) -> some View {
        let id = row["id"] as? String ?? ""
        let rowHighlighted = highlightedRowId == id
        return HStack(spacing: 0) {
            txColumn(width: colWidths[0], columnIndex: 0, alignment: .center) {
                Button {
                    if selected.contains(id) {
                        selected.remove(id)
                    } else {
                        selected.insert(id)
                    }
                } label: {
                    Image(systemName: selected.contains(id) ? "checkmark.square.fill" : "square")
                }
                .buttonStyle(.plain)
            }

            txColumn(width: colWidths[1], columnIndex: 1, alignment: .leading) {
                Text(shortDate(row["date"]))
                    .font(.caption.monospacedDigit())
            }

            txColumn(width: colWidths[2], columnIndex: 2, alignment: .leading) {
                Text(accountName(row["accountId"] as? String))
                    .font(.caption)
                    .lineLimit(1)
            }

            txColumn(width: colWidths[3], columnIndex: 3, alignment: .leading) {
                Text(categoryName((row["key"] as? String) ?? ""))
                    .font(.caption)
                    .lineLimit(1)
            }

            txColumn(width: colWidths[4], columnIndex: 4, alignment: .trailing) {
                Text(fmt(row["payment"]))
                    .font(.caption.monospacedDigit())
            }

            txColumn(width: colWidths[5], columnIndex: 5, alignment: .trailing) {
                Text(fmt(row["deposit"]))
                    .font(.caption.monospacedDigit())
            }

            txColumn(width: colWidths[6], columnIndex: 6, alignment: .trailing) {
                Text(fmt(row["balance"]))
                    .font(.caption.monospacedDigit())
            }

            txColumn(width: colWidths[7], columnIndex: 7, alignment: .leading) {
                NoteCell(
                    txId: id,
                    note: row["note"] as? String ?? "",
                    pendingNoteEdits: $pendingNoteEdits
                )
            }
        }
        .background {
            if rowHighlighted {
                Rectangle()
                    .fill(rowHighlightTint.opacity(0.14))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onRowHighlight(id)
        }
        .tableRowBottomSeparator(color: rowSeparatorColor, height: hairlineHeight)
    }

    private func txColumnBackground(_ columnIndex: Int) -> Color {
        columnIndex % 2 == 0
            ? Color.secondary.opacity(0.035)
            : Color.secondary.opacity(0.085)
    }

    private func txColumn<Content: View>(
        width: CGFloat,
        columnIndex: Int,
        alignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(width: width)
            .background(txColumnBackground(columnIndex))
    }

    private func fmt(_ v: Any?) -> String {
        let d: Double
        if let x = v as? Double {
            d = x
        } else if let n = v as? NSNumber {
            d = n.doubleValue
        } else if let s = v as? String, let x = Double(s) {
            d = x
        } else {
            return "—"
        }
        if abs(d) < 0.0001 { return "—" }
        return String(format: "%.0f", d)
    }

    private func accountName(_ id: String?) -> String {
        guard let id else { return "—" }
        return accounts.first(where: { $0.id == id })?.name ?? id
    }

    private func shortDate(_ v: Any?) -> String {
        let s = String(describing: v ?? "")
        if s.count > 16 { return String(s.prefix(16)) }
        return s
    }
}

private extension View {
    func tableRowBottomSeparator(color: Color, height: CGFloat) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(color)
                .frame(height: height)
        }
    }
}

private struct NoteCell: View {
    let txId: String
    let note: String
    @Binding var pendingNoteEdits: [String: String]

    @State private var text: String = ""

    var body: some View {
        TextField("Note", text: $text)
            .font(.caption)
            .onAppear {
                text = note
                syncPending()
            }
            .onChange(of: note) { _, n in
                text = n
                syncPending()
            }
            .onChange(of: text) { _, _ in
                syncPending()
            }
    }

    private func syncPending() {
        if text == note {
            pendingNoteEdits.removeValue(forKey: txId)
        } else {
            pendingNoteEdits[txId] = text
        }
    }
}
