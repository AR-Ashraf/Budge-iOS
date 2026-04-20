import Foundation

extension Notification.Name {
    /// Posted after account-affecting mutations (create/update/delete/transfer) so other screens can refresh snapshots.
    static let financeAccountsDidChange = Notification.Name("financeAccountsDidChange")
}

