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
        }
        .chartLegend(.visible)
        .frame(height: 220)
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
        .chartLegend(.visible)
        .frame(height: 220)
    }
}

private struct PieView: View {
    let spec: VisualizationSpec

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
            }
            .chartLegend(.visible)
            .frame(height: 220)
        }
    }
}

