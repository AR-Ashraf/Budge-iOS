import Foundation

/// Mirrors web `chatSuggestedPrompts` in `src/lib/constants.ts`.
enum ChatSuggestedPrompts {
    struct Item: Identifiable, Hashable {
        var id: String { title }
        let title: String
        let message: String
    }

    static let items: [Item] = [
        Item(title: "Setup Budget", message: "Help me setup my budgets"),
        Item(title: "Create Account", message: "Create an account named Savings Account with 1000 USD balance"),
        Item(title: "Check Balance", message: "What’s my current balance?"),
        Item(title: "Add Income", message: "I got 5k as salary today"),
        Item(title: "Add Expense", message: "I spent 1k on shopping today"),
        Item(title: "Transfer Fund", message: "I transferred 1k from my main account to my savings account"),
        Item(title: "Budget vs Actual", message: "Show this month’s budget vs actual in graphs"),
        Item(title: "Set Reminder", message: "Set a reminder to pay rent on the 1st"),
    ]
}
