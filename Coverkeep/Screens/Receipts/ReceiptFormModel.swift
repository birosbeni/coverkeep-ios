import Foundation
import SwiftData
import KeepCore

/// Editor state for capturing or editing a receipt: a label plus the page
/// drafts assembled through KeepCore's attachment pipeline. Pages persist
/// byte-for-byte — the archival promise lives here.
@Observable
final class ReceiptFormModel {
    /// Camera JPEG quality for receipts: fine print on thermal paper must
    /// survive, so captures are encoded once near-losslessly.
    static let archivalCameraQuality: CGFloat = 0.95

    var label: String = ""
    var drafts: [AttachmentDraft] = []

    private let editedReceipt: Receipt?

    var isEditing: Bool { editedReceipt != nil }

    /// A receipt without pages is not a receipt.
    var canSave: Bool { !drafts.isEmpty }

    init(receipt: Receipt? = nil) {
        self.editedReceipt = receipt
        if let receipt {
            label = receipt.label
            drafts = receipt.sortedPages.compactMap { page in
                guard let data = page.data else { return nil }
                return AttachmentDraft(fileName: page.fileName, kind: page.kind, data: data)
            }
        }
    }

    /// Persists the drafts as the receipt's pages, in strip order. On edit
    /// the pages are replaced wholesale — the drafts ARE the document.
    @discardableResult
    func save(for item: Item, in context: ModelContext) -> Receipt {
        let receipt = editedReceipt ?? Receipt()
        receipt.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.originalKept = true

        if editedReceipt == nil {
            receipt.item = item
            context.insert(receipt)
        } else {
            for page in receipt.pages ?? [] {
                context.delete(page)
            }
        }

        for (index, draft) in drafts.enumerated() {
            let page = ReceiptPage(
                fileName: draft.fileName,
                kind: draft.kind,
                pageIndex: index,
                data: draft.data
            )
            page.receipt = receipt
            context.insert(page)
        }
        return receipt
    }
}
