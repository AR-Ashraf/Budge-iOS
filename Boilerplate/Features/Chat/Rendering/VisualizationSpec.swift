import Foundation

struct VisualizationSpec: Decodable, Equatable {
    let type: String

    // Common fields
    let title: String?
    let subtype: String?

    // Table
    struct TableColumn: Decodable, Equatable {
        let key: String
        let label: String?
        let align: String?
    }
    let columns: [TableColumn]?
    let rows: [[String: JSONValue]]?

    // Charts
    struct SeriesPoint: Decodable, Equatable {
        let x: JSONValue?
        let y: JSONValue?
        let label: String?
        let value: Double?
    }

    struct Series: Decodable, Equatable {
        let name: String?
        let data: [SeriesPoint]
    }
    let series: [Series]?

    // Pie/doughnut
    struct PieDatum: Decodable, Equatable {
        let name: String
        let value: Double
        let color: String?
    }
    let data: [PieDatum]?

    // Progress (single metric)
    let value: Double?
    let goal: Double?

    static func decode(from json: String) -> VisualizationSpec? {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        do { return try decoder.decode(VisualizationSpec.self, from: data) } catch { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        title = try? c.decode(String.self, forKey: .title)
        subtype = try? c.decode(String.self, forKey: .subtype)

        // Charts
        series = try? c.decode([Series].self, forKey: .series)
        data = try? c.decode([PieDatum].self, forKey: .data)
        value = try? c.decode(Double.self, forKey: .value)
        goal = try? c.decode(Double.self, forKey: .goal)

        // Table (support both schemas):
        // 1) "web" schema: columns=[{key,label,align}], rows=[{key:value, ...}]
        // 2) "simple" schema: columns=["Date","Account",...], rows=[["2026-..","Main",...], ...]
        if let colsObj = try? c.decode([TableColumn].self, forKey: .columns) {
            columns = colsObj
            rows = try? c.decode([[String: JSONValue]].self, forKey: .rows)
        } else if let colsStr = try? c.decode([String].self, forKey: .columns) {
            let cols = colsStr.map { TableColumn(key: $0, label: $0, align: nil) }
            columns = cols

            if let rawRowArrays = try? c.decode([[JSONValue]].self, forKey: .rows) {
                let mapped: [[String: JSONValue]] = rawRowArrays.map { arr in
                    var dict: [String: JSONValue] = [:]
                    for (idx, col) in colsStr.enumerated() {
                        if idx < arr.count {
                            dict[col] = arr[idx]
                        } else {
                            dict[col] = .null
                        }
                    }
                    return dict
                }
                rows = mapped
            } else if let rawStringRows = try? c.decode([[String]].self, forKey: .rows) {
                let mapped: [[String: JSONValue]] = rawStringRows.map { arr in
                    var dict: [String: JSONValue] = [:]
                    for (idx, col) in colsStr.enumerated() {
                        dict[col] = idx < arr.count ? .string(arr[idx]) : .null
                    }
                    return dict
                }
                rows = mapped
            } else {
                rows = nil
            }
        } else {
            columns = nil
            rows = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case subtype
        case columns
        case rows
        case series
        case data
        case value
        case goal
    }
}

/// Minimal JSON "any" for decoding visualization rows and x/y values.
enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .null
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }
}

