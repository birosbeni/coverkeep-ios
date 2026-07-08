import Foundation
import SwiftData

/// The durable copy of a proof of purchase. Thermal paper fades; the photo
/// is the archive, so originals are never recompressed below archival
/// quality. A receipt is one document with one or more pages (photos or a
/// PDF) captured through KeepCore's attachment pipeline.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// no unique constraints; the `item` relationship is optional and its
/// inverse is declared on `Item.receipts`; `pages` declares its inverse
/// here on the to-many side.
@Model
final class Receipt {
    /// What this document is ("Receipt", "Warranty card", "Invoice"…).
    var label: String = ""
    /// True once the full-quality original is stored alongside any derived
    /// thumbnails or crops. Library picks and PDFs are byte-for-byte;
    /// camera captures are encoded once at archival quality.
    var originalKept: Bool = false
    var createdAt: Date = Date.now

    var item: Item?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptPage.receipt)
    var pages: [ReceiptPage]?

    var sortedPages: [ReceiptPage] {
        ReceiptPage.sorted(pages ?? [])
    }

    init(label: String = "", originalKept: Bool = false) {
        self.label = label
        self.originalKept = originalKept
        self.createdAt = .now
    }
}
