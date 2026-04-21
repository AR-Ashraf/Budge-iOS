import Charts
import SwiftUI

struct VisualizationView: View {
    let spec: VisualizationSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = spec.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            switch spec.type {
            case "table":
                TableView(spec: spec)
            case "pie", "doughnut":
                PieView(spec: spec)
            case "chart", "multi_chart", "bar", "line":
                SeriesChartView(spec: spec)
            case "scatter":
                ScatterView(spec: spec)
            default:
                Text("Unsupported visualization: \(spec.type)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TableView: View {
    let spec: VisualizationSpec

    var body: some View {
        let cols = spec.columns ?? []
        let rows = spec.rows ?? []

        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    ForEach(cols, id: \.key) { c in
                        Text(c.label ?? c.key)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(rows.indices, id: \.self) { idx in
                    let row = rows[idx]
                    GridRow {
                        ForEach(cols, id: \.key) { c in
                            Text(row[c.key]?.stringValue ?? "")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct SeriesChartView: View {
    let spec: VisualizationSpec
    @State private var selectedX: String?

    var body: some View {
        let series = spec.series ?? []
        let subtype = (spec.subtype ?? spec.type).lowercased()

        Chart {
            ForEach(series.indices, id: \.self) { sIdx in
                let s = series[sIdx]
                ForEach(s.data.indices, id: \.self) { pIdx in
                    let p = s.data[pIdx]
                    let xLabel = p.label ?? p.x?.stringValue ?? "\(pIdx + 1)"
                    let yVal = p.value ?? p.y?.doubleValue ?? 0

                    if subtype == "bar" {
                        BarMark(x: .value("X", xLabel), y: .value("Y", yVal))
                            .foregroundStyle(by: .value("Series", s.name ?? "Series"))
                    } else {
                        LineMark(x: .value("X", xLabel), y: .value("Y", yVal))
                            .foregroundStyle(by: .value("Series", s.name ?? "Series"))
                    }
                }
            }

            if let selectedX {
                RuleMark(x: .value("Selected", selectedX))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .topLeading, alignment: .leading) {
                        let rows = selectedRows(for: selectedX, in: series)
                        SelectionCalloutView(
                            title: selectedX,
                            rows: rows
                        )
                    }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
        .chartXSelection(value: $selectedX)
        .chartPlotStyle { plotArea in
            plotArea
                .background(AppTheme.Colors.surface.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(height: 220)
    }

    private func selectedRows(
        for x: String,
        in series: [VisualizationSpec.Series]
    ) -> [(label: String, value: Double)] {
        var out: [(String, Double)] = []
        for s in series {
            guard let name = s.name, !name.isEmpty else { continue }
            if let p = s.data.first(where: { ($0.label ?? $0.x?.stringValue) == x }) {
                out.append((name, p.value ?? p.y?.doubleValue ?? 0))
            }
        }
        return out
    }
}

private struct ScatterView: View {
    let spec: VisualizationSpec

    var body: some View {
        let series = spec.series ?? []

        Chart {
            ForEach(series.indices, id: \.self) { sIdx in
                let s = series[sIdx]
                ForEach(s.data.indices, id: \.self) { pIdx in
                    let p = s.data[pIdx]
                    let x = p.x?.doubleValue ?? 0
                    let y = p.y?.doubleValue ?? 0
                    PointMark(x: .value("X", x), y: .value("Y", y))
                        .foregroundStyle(by: .value("Series", s.name ?? "Series"))
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
        .chartPlotStyle { plotArea in
            plotArea
                .background(AppTheme.Colors.surface.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(height: 220)
    }
}

private struct PieView: View {
    let spec: VisualizationSpec
    @State private var selectedName: String?

    var body: some View {
        let data = spec.data ?? []
        if data.isEmpty {
            Text("No data")
                .foregroundStyle(.secondary)
        } else {
            Chart(data, id: \.name) { item in
                SectorMark(
                    angle: .value("Value", item.value),
                    innerRadius: .ratio(spec.type == "doughnut" ? 0.55 : 0.0)
                )
                .foregroundStyle(by: .value("Name", item.name))
                .opacity(selectedName == nil || selectedName == item.name ? 1.0 : 0.35)
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
            .frame(height: 220)

            // Tap targets for “show data on tap” (reliable & Apple-feeling).
            VStack(alignment: .leading, spacing: 6) {
                ForEach(data, id: \.name) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedName = (selectedName == item.name) ? nil : item.name
                        }
                    } label: {
                        HStack {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(NSNumber(value: item.value), formatter: NumberFormatter.decimalGrouped)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.Colors.surface.opacity(selectedName == item.name ? 0.55 : 0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(selectedName == item.name ? 0.45 : 0.20), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct SelectionCalloutView: View {
    let title: String
    let rows: [(label: String, value: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows.indices, id: \.self) { idx in
                let r = rows[idx]
                HStack(spacing: 8) {
                    Text(r.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(NSNumber(value: r.value), formatter: NumberFormatter.decimalGrouped)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

private extension NumberFormatter {
    static var decimalGrouped: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }
}

