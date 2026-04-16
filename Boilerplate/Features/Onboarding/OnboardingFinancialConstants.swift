import Foundation

/// Mirrors category sets from React `src/lib/constants.ts` for seeding `financialTypes`.
enum OnboardingUserType: String, CaseIterable, Identifiable {
    case jobHolder = "Job Holder"
    case entrepreneur = "Entrepreneur"
    case student = "Student"

    var id: String { rawValue }

    static func fromFirestore(_ value: Any?) -> OnboardingUserType? {
        guard let s = value as? String else { return nil }
        return OnboardingUserType(rawValue: s)
    }
}

struct FinancialCategorySeed: Hashable {
    let key: String
    let name: String
    let category: String // "income" | "expense"
}

enum OnboardingFinancialConstants {
    static let studentIncome: [FinancialCategorySeed] = [
        .init(key: "salary", name: "Salary / Campus Job", category: "income"),
        .init(key: "scholarship", name: "Scholarship / Grant / Stipend", category: "income"),
        .init(key: "freelance", name: "Freelance / Side Income", category: "income"),
        .init(key: "allowance", name: "Allowance / Family Support", category: "income"),
        .init(key: "refund", name: "Refunds / Reimbursements", category: "income"),
        .init(key: "interest", name: "Interest Income", category: "income"),
        .init(key: "others", name: "Other Income (Gifts etc.)", category: "income"),
    ]

    static let studentExpense: [FinancialCategorySeed] = [
        .init(key: "rent", name: "Housing (Dorm/Rent)", category: "expense"),
        .init(key: "utilities", name: "Utilities (Electricity/Internet/Gas)", category: "expense"),
        .init(key: "grocery", name: "Food & Groceries", category: "expense"),
        .init(key: "dining", name: "Dining / Coffee / Takeout", category: "expense"),
        .init(key: "transport", name: "Transport (Fuel/Rides/Public)", category: "expense"),
        .init(key: "phone", name: "Phone Bill", category: "expense"),
        .init(key: "education", name: "Education (Tuition/Books/Fees)", category: "expense"),
        .init(key: "subscriptions", name: "Subscriptions (Apps/Streaming)", category: "expense"),
        .init(key: "entertainment", name: "Entertainment / Streaming", category: "expense"),
        .init(key: "shopping", name: "Shopping & Personal Care", category: "expense"),
        .init(key: "health", name: "Health / Pharmacy", category: "expense"),
        .init(key: "savings", name: "Savings / Emergency Fund", category: "expense"),
        .init(key: "charity", name: "Charity / Donations", category: "expense"),
        .init(key: "bank_fees", name: "Bank Fees / ATM Cash", category: "expense"),
    ]

    static let jobHolderIncome: [FinancialCategorySeed] = [
        .init(key: "salary", name: "Salary / Wages", category: "income"),
        .init(key: "overtime", name: "Overtime / Bonus", category: "income"),
        .init(key: "tips", name: "Tips / Gratuities", category: "income"),
        .init(key: "freelance", name: "Freelance / Side Income", category: "income"),
        .init(key: "refund", name: "Refunds / Reimbursements", category: "income"),
        .init(key: "interest", name: "Interest Income", category: "income"),
        .init(key: "others", name: "Other Income (Gifts etc.)", category: "income"),
    ]

    static let jobHolderExpense: [FinancialCategorySeed] = [
        .init(key: "rent", name: "Housing (Rent/Mortgage)", category: "expense"),
        .init(key: "utilities", name: "Utilities (Electricity/Internet)", category: "expense"),
        .init(key: "grocery", name: "Food & Groceries", category: "expense"),
        .init(key: "transport", name: "Transport (Fuel/Rides/Public)", category: "expense"),
        .init(key: "phone", name: "Phone Bill", category: "expense"),
        .init(key: "insurance", name: "Insurance (Health/Auto/Life)", category: "expense"),
        .init(key: "debt", name: "Debt Payments (Loans/Cards)", category: "expense"),
        .init(key: "subscriptions", name: "Subscriptions", category: "expense"),
        .init(key: "dining", name: "Dining / Takeout", category: "expense"),
        .init(key: "shopping", name: "Shopping & Personal Needs", category: "expense"),
        .init(key: "health", name: "Health / Medical", category: "expense"),
        .init(key: "entertainment", name: "Entertainment / Streaming", category: "expense"),
        .init(key: "savings", name: "Savings / Emergency Fund", category: "expense"),
        .init(key: "charity", name: "Charity / Donations", category: "expense"),
        .init(key: "bank_fees", name: "Bank Fees / ATM Cash", category: "expense"),
        .init(key: "travel", name: "Travel / Commute (Parking/Tolls)", category: "expense"),
        .init(key: "clothing", name: "Clothing / Fashion", category: "expense"),
        .init(key: "fitness", name: "Fitness / Gym", category: "expense"),
    ]

    static let soloIncome: [FinancialCategorySeed] = [
        .init(key: "business", name: "Business Revenue (Sales/Invoices)", category: "income"),
        .init(key: "freelance", name: "Freelance / Consulting", category: "income"),
        .init(key: "commission", name: "Commission / Bonus", category: "income"),
        .init(key: "rental_inc", name: "Rental / Property Income", category: "income"),
        .init(key: "interest", name: "Interest Income", category: "income"),
        .init(key: "dividends", name: "Dividends / Investments", category: "income"),
        .init(key: "refund", name: "Refunds / Reimbursements", category: "income"),
        .init(key: "others", name: "Other Income (Grants/Gifts)", category: "income"),
    ]

    static let soloExpense: [FinancialCategorySeed] = [
        .init(key: "software", name: "Software & SaaS Tools", category: "expense"),
        .init(key: "marketing", name: "Marketing & Ads", category: "expense"),
        .init(key: "office", name: "Office / Equipment / Supplies", category: "expense"),
        .init(key: "contractors", name: "Freelancers / Contractor Payments", category: "expense"),
        .init(key: "taxes", name: "Taxes & Fees (Self-Employment/State/City)", category: "expense"),
        .init(key: "travel_work", name: "Travel for Work (Flights/Uber/Hotels)", category: "expense"),
        .init(key: "utilities", name: "Home Office (Utilities/Internet)", category: "expense"),
        .init(key: "rent", name: "Workspace Rent (Home Office Allocation)", category: "expense"),
        .init(key: "grocery", name: "Food & Groceries", category: "expense"),
        .init(key: "dining", name: "Dining / Client Meals", category: "expense"),
        .init(key: "transport", name: "Transport (Fuel/Rides/Public)", category: "expense"),
        .init(key: "phone", name: "Phone Bill", category: "expense"),
        .init(key: "insurance", name: "Insurance (Health/Business/Auto)", category: "expense"),
        .init(key: "subscriptions", name: "Subscriptions", category: "expense"),
        .init(key: "health", name: "Health / Medical", category: "expense"),
        .init(key: "education", name: "Education / Courses", category: "expense"),
        .init(key: "entertainment", name: "Entertainment / Streaming", category: "expense"),
        .init(key: "savings", name: "Savings / Emergency Fund", category: "expense"),
        .init(key: "charity", name: "Charity / Donations", category: "expense"),
        .init(key: "bank_fees", name: "Bank Fees / ATM Cash", category: "expense"),
    ]

    static func categories(for userType: OnboardingUserType) -> (income: [FinancialCategorySeed], expense: [FinancialCategorySeed]) {
        switch userType {
        case .jobHolder:
            return (jobHolderIncome, jobHolderExpense)
        case .entrepreneur:
            return (soloIncome, soloExpense)
        case .student:
            return (studentIncome, studentExpense)
        }
    }
}
