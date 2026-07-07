import Foundation
import SwiftData

/// The durable copy of a proof of purchase. Thermal paper fades; the photo
/// is the archive, so originals are never recompressed below archival
/// quality.
///
/// Attachment payloads (photos, PDF pages) arrive in Slice 2 through
/// KeepCore's attachment pipeline; Slice 0 carries only the archival flags.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// no unique constraints; the `item` relationship is optional and its
/// inverse is declared on `Item.receipts`.
@Model
final class Receipt {
    /// True once the full-quality original is stored alongside any derived
    /// thumbnails or crops.
    var originalKept: Bool = false
    var createdAt: Date = Date.now

    var item: Item?

    init(originalKept: Bool = false) {
        self.originalKept = originalKept
        self.createdAt = .now
    }
}
