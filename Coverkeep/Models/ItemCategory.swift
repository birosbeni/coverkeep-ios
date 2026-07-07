import Foundation

/// What kind of thing was bought. Stored as a raw string on `Item` so the
/// SwiftData schema stays CloudKit-compatible (enums are not persisted
/// directly).
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case electronics
    case appliance
    case furniture
    case tool
    case sportsAndOutdoor
    case clothing
    case jewelry
    case vehicle
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .electronics: String(localized: "Electronics")
        case .appliance: String(localized: "Appliance")
        case .furniture: String(localized: "Furniture")
        case .tool: String(localized: "Tool")
        case .sportsAndOutdoor: String(localized: "Sports & outdoor")
        case .clothing: String(localized: "Clothing")
        case .jewelry: String(localized: "Jewelry")
        case .vehicle: String(localized: "Vehicle")
        case .other: String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .electronics: "laptopcomputer"
        case .appliance: "refrigerator"
        case .furniture: "sofa"
        case .tool: "wrench.and.screwdriver"
        case .sportsAndOutdoor: "figure.hiking"
        case .clothing: "tshirt"
        case .jewelry: "sparkles"
        case .vehicle: "car"
        case .other: "shippingbox"
        }
    }
}

/// Whether a coverage row was computed by the WarrantyRules engine or
/// entered by hand. Computed coverages show their rule source in the UI;
/// manual ones are the user's own truth.
enum CoverageSource: String, Codable, CaseIterable {
    case computedFromRules
    case manual
}

/// What happened to an item after purchase.
enum EventKind: String, Codable, CaseIterable {
    case claim
    case repair
    case returned
    case other
}
