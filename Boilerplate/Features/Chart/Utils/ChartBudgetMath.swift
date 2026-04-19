import Foundation

enum ChartBudgetMath {
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func doubleValue(_ row: [String: Any], key: String) -> Double {
        if let d = row[key] as? Double { return d }
        if let n = row[key] as? NSNumber { return n.doubleValue }
        if let s = row[key] as? String { return Double(s) ?? 0 }
        return 0
    }

    /// Matches web `getMonthlyTotalRow`: sums each month across category rows (excludes appended totals row if re-summed).
    static func monthlyTotalsRow(from rows: [[String: Any]], title: String = "Totals") -> [String: Any] {
        let dataRows = rows.filter { ($0["key"] as? String) != "__monthly_totals__" }
        var row: [String: Any] = [
            "id": "monthly-totals",
            "key": "__monthly_totals__",
            "title": title,
            "category": "totals",
        ]
        for m in months {
            row[m] = dataRows.reduce(0.0) { $0 + doubleValue($1, key: m) }
        }
        return row
    }

    /// Appended totals band row (web: `title` is `"Totals"`, non-selectable).
    static func isTotalsMetaRow(_ row: [String: Any]) -> Bool {
        (row["key"] as? String) == "__monthly_totals__"
    }

    static func summaryRows(income: [[String: Any]], expense: [[String: Any]], year _: Int) -> [[String: Any]] {
        var incTot: [String: Any] = ["id": "sum-inc", "title": "Total Income", "key": "income"]
        var expTot: [String: Any] = ["id": "sum-exp", "title": "Total Expense", "key": "expense"]
        var net: [String: Any] = ["id": "sum-net", "title": "Net", "key": "net"]
        for m in months {
            let i = income.reduce(0.0) { $0 + doubleValue($1, key: m) }
            let e = expense.reduce(0.0) { $0 + doubleValue($1, key: m) }
            incTot[m] = i
            expTot[m] = e
            net[m] = i - e
        }
        return [incTot, expTot, net]
    }
}
