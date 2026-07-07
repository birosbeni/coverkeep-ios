import Foundation

/// The kinds of protection a purchase can carry. Multiple coverages per item
/// is the norm: a withdrawal window, the legal guarantee, and a manufacturer
/// warranty routinely coexist.
public enum CoverageKind: String, Codable, Sendable, CaseIterable {
    /// The statutory conformity guarantee (EU: 2 years minimum) the seller
    /// owes regardless of any voluntary warranty.
    case legalGuarantee
    /// A warranty granted by the manufacturer or mandated by national law
    /// (e.g. the Hungarian jótállás), distinct from the legal guarantee.
    case commercialWarranty
    /// A warranty extension bought separately.
    case extendedWarranty
    /// The 14-day distance-selling withdrawal (cooling-off) right.
    case withdrawal
}

/// Where the purchase happened. Distance-selling rights (withdrawal) only
/// attach to online purchases.
public enum PurchaseChannel: String, Codable, Sendable, CaseIterable {
    case inStore
    case online
}
