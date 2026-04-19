import Foundation

/// Parity with `src/lib/csvUtils.ts` — same section headers and escaping rules.
enum ChartCSVExporter {
    private static func escapeCSV(_ value: Any?) -> String {
        let str = String(describing: value ?? "")
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }

    private static let months = ChartBudgetMath.months

    static func budgetCSV(
        income: [[String: Any]],
        expense: [[String: Any]],
        startingBalance: Double,
        currentBalance: Double,
        year: Int
    ) -> String {
        let currentDate = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateStyle = .medium

        let monthlyIncome = months.map { m in income.reduce(0.0) { $0 + ChartBudgetMath.doubleValue($1, key: m) } }
        let monthlyExpense = months.map { m in expense.reduce(0.0) { $0 + ChartBudgetMath.doubleValue($1, key: m) } }
        let monthlyNet = zip(monthlyIncome, monthlyExpense).map { $0 - $1 }

        var lines: [String] = []
        lines.append("BUDGET REPORT")
        lines.append("Generated on: \(df.string(from: currentDate))")
        let period = DateFormatter()
        period.locale = Locale(identifier: "en_US_POSIX")
        period.dateFormat = "MMMM yyyy"
        let comp = DateComponents(calendar: Calendar.current, year: year, month: Calendar.current.component(.month, from: currentDate), day: 1)
        let periodDate = Calendar.current.date(from: comp) ?? currentDate
        lines.append("Period: \(period.string(from: periodDate))")
        lines.append("")
        lines.append("BALANCE")
        lines.append("Starting Balance,\(startingBalance)")
        lines.append("Current Balance,\(currentBalance)")
        lines.append("")
        lines.append("SUMMARY")
        lines.append(",\(months.joined(separator: ","))")
        lines.append("Income,\(monthlyIncome.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("Expense,\(monthlyExpense.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("Net Budget,\(monthlyNet.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("")
        lines.append("INCOME CATEGORIES")
        lines.append("Category,\(months.joined(separator: ","))")
        for item in income {
            let name = escapeCSV(item["title"] ?? item["name"] ?? item["key"] ?? "Unknown")
            let mv = months.map { escapeCSV(ChartBudgetMath.doubleValue(item, key: $0)) }
            lines.append("\(name),\(mv.joined(separator: ","))")
        }
        lines.append("Total,\(monthlyIncome.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("")
        lines.append("EXPENSE CATEGORIES")
        lines.append("Category,\(months.joined(separator: ","))")
        for item in expense {
            let name = escapeCSV(item["title"] ?? item["name"] ?? item["key"] ?? "Unknown")
            let mv = months.map { escapeCSV(ChartBudgetMath.doubleValue(item, key: $0)) }
            lines.append("\(name),\(mv.joined(separator: ","))")
        }
        lines.append("Total,\(monthlyExpense.map { escapeCSV($0) }.joined(separator: ","))")
        return lines.joined(separator: "\n")
    }

    static func yearlyCSV(
        income: [[String: Any]],
        expense: [[String: Any]],
        startingBalance: Double,
        currentBalance: Double,
        year: Int
    ) -> String {
        let currentDate = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateStyle = .medium

        let monthlyIncome = months.map { m in income.reduce(0.0) { $0 + ChartBudgetMath.doubleValue($1, key: m) } }
        let monthlyExpense = months.map { m in expense.reduce(0.0) { $0 + ChartBudgetMath.doubleValue($1, key: m) } }
        let monthlyNet = zip(monthlyIncome, monthlyExpense).map { $0 - $1 }

        var lines: [String] = []
        lines.append("YEARLY REPORT")
        lines.append("Generated on: \(df.string(from: currentDate))")
        lines.append("Year: \(year)")
        lines.append("")
        lines.append("BALANCE")
        lines.append("Starting Balance,\(startingBalance)")
        lines.append("Current Balance,\(currentBalance)")
        lines.append("")
        lines.append("SUMMARY")
        lines.append(",\(months.joined(separator: ","))")
        lines.append("Income,\(monthlyIncome.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("Expense,\(monthlyExpense.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("Net Amount,\(monthlyNet.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("")
        lines.append("INCOME CATEGORIES")
        lines.append("Category,\(months.joined(separator: ","))")
        for item in income {
            let name = escapeCSV(item["title"] ?? item["name"] ?? item["key"] ?? "Unknown")
            let mv = months.map { escapeCSV(ChartBudgetMath.doubleValue(item, key: $0)) }
            lines.append("\(name),\(mv.joined(separator: ","))")
        }
        lines.append("Total,\(monthlyIncome.map { escapeCSV($0) }.joined(separator: ","))")
        lines.append("")
        lines.append("EXPENSE CATEGORIES")
        lines.append("Category,\(months.joined(separator: ","))")
        for item in expense {
            let name = escapeCSV(item["title"] ?? item["name"] ?? item["key"] ?? "Unknown")
            let mv = months.map { escapeCSV(ChartBudgetMath.doubleValue(item, key: $0)) }
            lines.append("\(name),\(mv.joined(separator: ","))")
        }
        lines.append("Total,\(monthlyExpense.map { escapeCSV($0) }.joined(separator: ","))")
        return lines.joined(separator: "\n")
    }

    static func transactionsCSV(
        rows: [[String: Any]],
        categoryName: (String) -> String
    ) -> String {
        let headers = ["Date", "Category", "Type", "Amount", "Balance"]
        var lines: [String] = [headers.joined(separator: ",")]
        for item in rows {
            let dateStr = String(describing: item["date"] ?? "N/A")
            let key = item["key"] as? String ?? ""
            let cat = categoryName(key)
            let payment = ChartBudgetMath.doubleValue(item, key: "payment")
            let deposit = ChartBudgetMath.doubleValue(item, key: "deposit")
            let typ = payment > 0 ? "Expense" : (deposit > 0 ? "Income" : "Unknown")
            let amount = payment > 0 ? payment : deposit
            let bal = ChartBudgetMath.doubleValue(item, key: "balance")
            let row: [String] = [
                escapeCSV(dateStr),
                escapeCSV(cat),
                escapeCSV(typ),
                escapeCSV(amount),
                escapeCSV(bal),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
