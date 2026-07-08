import Foundation
import SwiftData
import Testing
import KeepCore
@testable import Coverkeep

@Suite("Receipts")
@MainActor
struct ReceiptTests {

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeItem(in context: ModelContext) -> Item {
        let item = Item(name: "Vacuum")
        context.insert(item)
        return item
    }

    // MARK: The archival promise

    @Test("pages persist byte-for-byte — the photo is the durable copy")
    func byteFidelity() throws {
        let context = try makeContext()
        let item = makeItem(in: context)

        let original = Data((0..<4096).map { UInt8($0 % 251) })
        let model = ReceiptFormModel()
        model.drafts = [AttachmentDraft(fileName: "receipt.jpg", kind: .photo, data: original)]
        let receipt = model.save(for: item, in: context)
        try context.save()

        let page = try #require(receipt.sortedPages.first)
        #expect(page.data == original)
        #expect(receipt.originalKept)
    }

    @Test("camera captures for receipts use archival quality, above KeepCore's default")
    func archivalCameraQuality() {
        #expect(ReceiptFormModel.archivalCameraQuality >= 0.95)
    }

    // MARK: Multi-page receipts

    @Test("a long receipt photographed in sections stays one ordered document")
    func multiPageOrdering() throws {
        let context = try makeContext()
        let item = makeItem(in: context)

        let model = ReceiptFormModel()
        model.label = "IKEA receipt"
        model.drafts = (1...3).map { index in
            AttachmentDraft(
                fileName: "section-\(index).jpg",
                kind: .photo,
                data: Data("page \(index)".utf8)
            )
        }
        let receipt = model.save(for: item, in: context)
        try context.save()

        let pages = receipt.sortedPages
        #expect(pages.count == 3)
        #expect(pages.map(\.fileName) == ["section-1.jpg", "section-2.jpg", "section-3.jpg"])
        #expect(pages.map(\.pageIndex) == [0, 1, 2])
        #expect(receipt.label == "IKEA receipt")
    }

    @Test("mixed photo and PDF pages keep their kinds")
    func mixedKinds() throws {
        let context = try makeContext()
        let item = makeItem(in: context)

        let model = ReceiptFormModel()
        model.drafts = [
            AttachmentDraft(fileName: "front.jpg", kind: .photo, data: Data("photo".utf8)),
            AttachmentDraft(fileName: "invoice.pdf", kind: .pdf, data: Data("%PDF".utf8)),
        ]
        let receipt = model.save(for: item, in: context)
        try context.save()

        #expect(receipt.sortedPages.map(\.kind) == [.photo, .pdf])
    }

    // MARK: Editing

    @Test("editing replaces the pages wholesale — the drafts are the document")
    func editReplacesPages() throws {
        let context = try makeContext()
        let item = makeItem(in: context)

        let model = ReceiptFormModel()
        model.drafts = [
            AttachmentDraft(fileName: "old-1.jpg", kind: .photo, data: Data("old 1".utf8)),
            AttachmentDraft(fileName: "old-2.jpg", kind: .photo, data: Data("old 2".utf8)),
        ]
        let receipt = model.save(for: item, in: context)
        try context.save()

        let editModel = ReceiptFormModel(receipt: receipt)
        #expect(editModel.drafts.count == 2) // existing pages load as drafts
        editModel.drafts.removeFirst()
        editModel.drafts.append(
            AttachmentDraft(fileName: "new.jpg", kind: .photo, data: Data("new".utf8))
        )
        editModel.save(for: item, in: context)
        try context.save()

        let pages = receipt.sortedPages
        #expect(pages.map(\.fileName) == ["old-2.jpg", "new.jpg"])
        #expect(pages.map(\.pageIndex) == [0, 1])
        let allPages = try context.fetch(FetchDescriptor<ReceiptPage>())
        #expect(allPages.count == 2) // no orphaned pages left behind
    }

    @Test("a receipt needs at least one page to be savable")
    func emptyDraftsBlocked() {
        let model = ReceiptFormModel()
        #expect(!model.canSave)
        model.drafts = [AttachmentDraft(fileName: "r.jpg", kind: .photo, data: Data([1]))]
        #expect(model.canSave)
    }

    // MARK: Cascades

    @Test("deleting a receipt removes its pages; deleting the item removes everything")
    func cascades() throws {
        let context = try makeContext()
        let item = makeItem(in: context)

        for label in ["first", "second"] {
            let model = ReceiptFormModel()
            model.label = label
            model.drafts = [
                AttachmentDraft(fileName: "\(label).jpg", kind: .photo, data: Data(label.utf8))
            ]
            model.save(for: item, in: context)
        }
        try context.save()

        let firstReceipt = try #require(
            (item.receipts ?? []).first { $0.label == "first" }
        )
        context.delete(firstReceipt)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ReceiptPage>()).count == 1)

        context.delete(item)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Receipt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReceiptPage>()).isEmpty)
    }
}
