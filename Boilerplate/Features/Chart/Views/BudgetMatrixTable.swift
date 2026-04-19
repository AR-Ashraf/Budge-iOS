import SwiftUI
import UIKit

struct BudgetMatrixTable: View {
    let title: String
    let rows: [[String: Any]]
    let editable: Bool
    let rowCategory: String
    @Binding var selected: Set<String>
    let monthKeys: [String]
    /// Draft edits not yet saved (toolbar Save). Key: `type:key:monthKey`.
    @Binding var pendingEdits: [String: PendingBudgetCellEdit]

    /// Web parity: `brandGreenPrimary` vertical rules on the current calendar month column (`headIndex === currentMonthCol`).
    let accentColor: Color
    /// Row tap highlight (`rowCategory:key`).
    let highlightedRowId: String?
    let onRowHighlight: (String) -> Void

    private let categoryColumnWidth: CGFloat = 140
    private let monthColumnWidth: CGFloat = 56

    private var rowSeparatorColor: Color { Color.primary.opacity(0.12) }

    private var hairlineHeight: CGFloat { 1.0 / max(UIScreen.main.scale, 2.0) }

    /// 1 = Jan … 12 = Dec — matches column index for month columns (category is 0).
    private var currentMonthColumnIndex: Int {
        Calendar.current.component(.month, from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        dataRow(row: row)
                    }
                }
            }
        }
    }

    /// Alternating column bands; month columns only (no trailing Total column — totals are a bottom row, web-style).
    private func columnBackground(forColumn columnIndex: Int) -> Color {
        if columnIndex == 0 {
            return Color.secondary.opacity(0.06)
        }
        return (columnIndex - 1) % 2 == 0
            ? Color.secondary.opacity(0.035)
            : Color.secondary.opacity(0.085)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            matrixColumn(
                width: categoryColumnWidth,
                columnIndex: 0,
                alignment: .leading
            ) {
                Text("Category")
                    .font(.caption2.weight(.bold))
            }
            ForEach(Array(monthKeys.enumerated()), id: \.offset) { i, m in
                matrixColumn(
                    width: monthColumnWidth,
                    columnIndex: i + 1,
                    alignment: .trailing
                ) {
                    Text(m)
                        .font(.caption2.weight(.bold))
                }
            }
        }
        .tableRowBottomSeparator(color: rowSeparatorColor, height: hairlineHeight)
    }

    private func dataRow(row: [String: Any]) -> some View {
        let key = row["key"] as? String ?? ""
        let titleText = String(describing: row["title"] ?? row["name"] ?? key)
        let rowId = "\(rowCategory):\(key)"
        let isTotalsMeta = ChartBudgetMath.isTotalsMetaRow(row)
        let isSelectable = editable && rowCategory != "summary" && !isTotalsMeta

        let rowHighlighted = highlightedRowId == rowId

        return HStack(alignment: .top, spacing: 0) {
            matrixColumn(
                width: categoryColumnWidth,
                columnIndex: 0,
                alignment: .leading
            ) {
                if isSelectable {
                    HStack(spacing: 6) {
                        Button {
                            if selected.contains(rowId) {
                                selected.remove(rowId)
                            } else {
                                selected.insert(rowId)
                            }
                        } label: {
                            Image(systemName: selected.contains(rowId) ? "checkmark.square.fill" : "square")
                        }
                        .buttonStyle(.plain)
                        Text(titleText)
                            .font(isTotalsMeta ? .caption.weight(.semibold) : .caption)
                            .lineLimit(2)
                    }
                } else {
                    Text(titleText)
                        .font(isTotalsMeta ? .caption.weight(.semibold) : .caption)
                }
            }

            ForEach(Array(monthKeys.enumerated()), id: \.offset) { i, m in
                matrixColumn(
                    width: monthColumnWidth,
                    columnIndex: i + 1,
                    alignment: .trailing
                ) {
                    if isTotalsMeta {
                        Text(formatInt(ChartBudgetMath.doubleValue(row, key: m)))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    } else {
                        BudgetCell(
                            rowCategory: rowCategory,
                            rowKey: row["key"] as? String ?? "",
                            monthKey: m,
                            value: ChartBudgetMath.doubleValue(row, key: m),
                            editable: editable && rowCategory != "summary",
                            pendingEdits: $pendingEdits
                        )
                    }
                }
            }
        }
        .background {
            if rowHighlighted {
                Rectangle()
                    .fill(accentColor.opacity(0.14))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onRowHighlight(rowId)
        }
        .tableRowBottomSeparator(color: rowSeparatorColor, height: hairlineHeight)
        .overlay(alignment: .top) {
            if isTotalsMeta {
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(height: 2)
            }
        }
    }

    /// Full-height column tint; content is inset so header/body columns line up (web `Td` style).
    private func matrixColumn<Content: View>(
        width: CGFloat,
        columnIndex: Int,
        alignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCurrentMonthColumn = columnIndex > 0 && columnIndex == currentMonthColumnIndex
        return content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(width: width)
            .background(columnBackground(forColumn: columnIndex))
            .overlay(alignment: .leading) {
                if isCurrentMonthColumn {
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 1)
                }
            }
            .overlay(alignment: .trailing) {
                if isCurrentMonthColumn {
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 1)
                }
            }
    }

    private func formatInt(_ v: Double) -> String {
        let n = NSNumber(value: v)
        let f = NumberFormatter()
        f.maximumFractionDigits = 0
        return f.string(from: n) ?? String(Int(v))
    }
}

private struct BudgetCell: View {
    let rowCategory: String
    let rowKey: String
    let monthKey: String
    let value: Double
    let editable: Bool
    @Binding var pendingEdits: [String: PendingBudgetCellEdit]

    @State private var text: String = ""

    private var cellId: String { "\(rowCategory):\(rowKey):\(monthKey)" }

    var body: some View {
        Group {
            if editable {
                TextField("", text: $text)
                    .font(.caption.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .onAppear {
                        text = value == 0 ? "" : String(format: "%.0f", value)
                        syncPending()
                    }
                    .onChange(of: value) { _, v in
                        text = v == 0 ? "" : String(format: "%.0f", v)
                        syncPending()
                    }
                    .onChange(of: text) { _, _ in
                        syncPending()
                    }
            } else {
                Text(value == 0 ? "—" : String(format: "%.0f", value))
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func parsedAmount(from raw: String) -> Double {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return 0 }
        return Double(t.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private func amountsEqual(_ a: Double, _ b: Double) -> Bool {
        Int(a.rounded()) == Int(b.rounded())
    }

    private func syncPending() {
        guard editable else { return }
        let parsed = parsedAmount(from: text)
        if amountsEqual(parsed, value) {
            pendingEdits.removeValue(forKey: cellId)
        } else {
            pendingEdits[cellId] = PendingBudgetCellEdit(
                type: rowCategory,
                key: rowKey,
                monthKey: monthKey,
                amount: parsed
            )
        }
    }
}

// MARK: - Hairline row separator

private extension View {
    func tableRowBottomSeparator(color: Color, height: CGFloat) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(color)
                .frame(height: height)
        }
    }
}
