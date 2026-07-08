import Foundation
import SwiftData
import KeepCore

/// One page of a receipt — a photo or a PDF, stored byte-for-byte at
/// archival quality. Thermal paper fades; these bytes are the durable copy
/// and are never recompressed after capture.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// no unique constraints; the `receipt` relationship is optional and its
/// inverse is declared on `Receipt.pages`.
@Model
final class ReceiptPage {
    var fileName: String = ""
    /// Raw `KeepCore.AttachmentKind` (photo/pdf).
    var kindRawValue: String = AttachmentKind.photo.rawValue
    /// Position within the receipt; multi-page receipts are the norm for
    /// long thermal rolls photographed in sections.
    var pageIndex: Int = 0
    var createdAt: Date = Date.now

    /// The archival bytes, kept outside the main store.
    @Attribute(.externalStorage) var data: Data?

    var receipt: Receipt?

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRawValue) ?? .photo }
        set { kindRawValue = newValue.rawValue }
    }

    init(fileName: String, kind: AttachmentKind, pageIndex: Int, data: Data) {
        self.fileName = fileName
        self.kindRawValue = kind.rawValue
        self.pageIndex = pageIndex
        self.data = data
        self.createdAt = .now
    }

    /// Pages sorted for display; index is the source of truth, creation
    /// time the tiebreaker.
    static func sorted(_ pages: [ReceiptPage]) -> [ReceiptPage] {
        pages.sorted {
            ($0.pageIndex, $0.createdAt) < ($1.pageIndex, $1.createdAt)
        }
    }
}
