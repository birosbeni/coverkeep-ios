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
