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

