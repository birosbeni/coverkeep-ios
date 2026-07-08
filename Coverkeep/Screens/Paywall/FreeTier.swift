import Foundation
import KeepCore

/// Coverkeep Pro product identifiers. KeepCore's PurchaseManager carries no
/// app literals by design; these are the app's. They must match
/// `Coverkeep.storekit` and, later, App Store Connect exactly.
enum CoverkeepProducts {
    static let annual = "com.birosbenedek.coverkeep.pro.annual"
    static let monthly = "com.birosbenedek.coverkeep.pro.monthly"
    static let lifetime = "com.birosbenedek.coverkeep.pro.lifetime"

    static var ids: PurchaseManager.ProductIDs {
        .init(annual: annual, monthly: monthly, lifetime: lifetime)
    }
}

/// The hard-ish paywall policy (CLAUDE.md §4, Slice 6): free = 10 items,
/// FULL-featured — receipts, coverages, events, reminders, search, and
/// export all work on every item, free or not. Only creating an 11th item
/// is gated; existing data is never locked away.
///
/// Archived items count toward the limit (archiving is organization, not a
/// slot-freeing trick); deleting frees the slot.
enum FreeTier {
    static let maxItems = 10

    static func canCreateItem(existingItemCount: Int, isEntitled: Bool) -> Bool {
        isEntitled || existingItemCount < maxItems
    }
}
