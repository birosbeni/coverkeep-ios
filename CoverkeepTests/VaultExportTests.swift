import Foundation
import SwiftData
import Testing
import KeepCore
import WarrantyRules
@testable import Coverkeep

@Suite("Vault export")
@MainActor
struct VaultExportTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A vault exercising every exported shape: two items (one archived),
    /// computed + manual coverages, a two-page receipt sharing a file name
    /// with another receipt's page (dedup), and events with and without
    /// attachments.
    private func makeVault() throws -> (ModelContext, [Item]) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let laptop = Item(
            name: "Laptop", category: .electronics, brand: "Apple",
            purchaseDate: date(2026, 7, 1), deliveryDate: date(2026, 7, 3),
            priceAmount: Decimal(string: "649990.10"), currencyCode: "HUF",
            seller: "iStore", channel: .online, countryCode: "HU"
        )
        context.insert(laptop)
        CoverageDerivation.regenerateComputedCoverages(
            for: laptop, engine: .shared, in: context, calendar: calendar
        )
        let manual = Coverage(
            kind: .extendedWarranty, startDate: date(2026, 7, 3), endDate: date(2031, 7, 3)
        )
        manual.item = laptop
        context.insert(manual)

        let receiptModel = ReceiptFormModel()
        receiptModel.label = "Purchase receipt"
        receiptModel.drafts = [
            AttachmentDraft(fileName: "receipt.jpg", kind: .photo, data: Data("page-1".utf8)),
            AttachmentDraft(fileName: "receipt.jpg", kind: .photo, data: Data("page-2".utf8)),
        ]
        receiptModel.save(for: laptop, in: context)

        let claim = Event(date: date(2026, 7, 5), kind: .claim, note: "Dead pixel")
        claim.setAttachment(
            AttachmentDraft(fileName: "quote.pdf", kind: .pdf, data: Data("%PDF quote".utf8))
        )
        claim.item = laptop
        context.insert(claim)
        let repair = Event(date: date(2026, 7, 6), kind: .repair, note: "Panel replaced")
        repair.item = laptop
        context.insert(repair)

        let oldPhone = Item(name: "Old phone", countryCode: "HU")
        oldPhone.archived = true
        context.insert(oldPhone)
        let phoneReceipt = ReceiptFormModel()
        phoneReceipt.drafts = [
            AttachmentDraft(fileName: "receipt.jpg", kind: .photo, data: Data("phone".utf8))
        ]
        phoneReceipt.save(for: oldPhone, in: context)

        try context.save()
        return (context, [laptop, oldPhone])
    }

    @Test("the document is full fidelity: fields, provenance, exact money")
    func documentFidelity() throws {
        let (_, items) = try makeVault()
        let prepared = VaultExport.prepare(items: items, exportedAt: date(2026, 7, 8))

        #expect(prepared.document.schemaVersion == 1)
        #expect(prepared.document.items.count == 2) // archived items included

        let laptop = try #require(prepared.document.items.first { $0.name == "Laptop" })
        #expect(laptop.price == "649990.1") // Decimal string, not a float artifact
        #expect(laptop.channel == "online")
        #expect(laptop.deliveryDate != nil)

        let guarantee = try #require(
            laptop.coverages.first { $0.kind == "legalGuarantee" }
        )
        #expect(guarantee.source == "computedFromRules")
        #expect(guarantee.ruleID == "hu.legal-guarantee")
        #expect(guarantee.ruleSetID == "HU")
        #expect(guarantee.ruleSetVersion == "2026-07")

        #expect(laptop.coverages.contains { $0.kind == "extendedWarranty" && $0.source == "manual" })
        #expect(prepared.document.items.contains { $0.archived })
    }

    @Test("JSON file references and written attachments agree, collisions deduped")
    func referencesMatchAttachments() throws {
        let (_, items) = try makeVault()
        let prepared = VaultExport.prepare(items: items, exportedAt: date(2026, 7, 8))

        let referenced = prepared.document.items.flatMap { item in
            item.receipts.flatMap(\.pageFiles) + item.events.compactMap(\.attachmentFile)
        }
        let assigned = Set(
            ExportArchiveBuilder.assignedNames(for: prepared.attachments).values
        )

        // 3 "receipt.jpg" pages + 1 quote.pdf, all referenced exactly once.
        #expect(referenced.count == 4)
        #expect(Set(referenced).count == 4)
        #expect(Set(referenced) == assigned)
        #expect(referenced.filter { $0.hasPrefix("receipt") }.count == 3)

        let laptop = try #require(prepared.document.items.first { $0.name == "Laptop" })
        let claim = try #require(laptop.events.first { $0.kind == "claim" })
        #expect(claim.attachmentFile?.hasSuffix(".pdf") == true)
        let repair = try #require(laptop.events.first { $0.kind == "repair" })
        #expect(repair.attachmentFile == nil)
    }

    @Test("page references stay in page order after dedup renaming")
    func pageOrderSurvivesDedup() throws {
        let (_, items) = try makeVault()
        let prepared = VaultExport.prepare(items: items, exportedAt: date(2026, 7, 8))
        let laptop = try #require(prepared.document.items.first { $0.name == "Laptop" })
        let pageFiles = try #require(laptop.receipts.first?.pageFiles)
        #expect(pageFiles.count == 2)
        // Page 1 was created before page 2, so it gets the unsuffixed name.
        #expect(pageFiles[0] == "receipt.jpg")
        #expect(pageFiles[1].hasPrefix("receipt-"))
    }

    @Test("the document round-trips byte-stably through the deterministic encoder")
    func encodeDecodeRoundTrip() throws {
        let (_, items) = try makeVault()
        let prepared = VaultExport.prepare(items: items, exportedAt: date(2026, 7, 8))
        let data = try DeterministicJSON.encoder().encode(prepared.document)

        // ISO-8601 truncates sub-second precision, so decoded Dates differ
        // from in-memory ones by milliseconds; the real determinism property
        // is that decode → re-encode reproduces the bytes exactly.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportDocument.self, from: data)
        let reencoded = try DeterministicJSON.encoder().encode(decoded)
        #expect(reencoded == data)
        #expect(decoded.items.map(\.name) == prepared.document.items.map(\.name))
    }

    @Test("the archive builds as a real zip on disk")
    func archiveBuilds() throws {
        let (_, items) = try makeVault()
        let url = try VaultExport.makeArchive(items: items, exportedAt: date(2026, 7, 8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Coverkeep Export.zip")
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        #expect((size ?? 0) > 0)
        // ZIP magic bytes: PK\x03\x04.
        let handle = try FileHandle(forReadingFrom: url)
        let magic = try handle.read(upToCount: 4)
        try handle.close()
        #expect(magic == Data([0x50, 0x4B, 0x03, 0x04]))
    }

    @Test("an event attachment round-trips through the store")
    func eventAttachmentRoundTrip() throws {
        let (context, items) = try makeVault()
        let laptop = items[0]
        let claim = try #require((laptop.events ?? []).first { $0.kind == .claim })
        let draft = try #require(claim.attachmentDraft)
        #expect(draft.fileName == "quote.pdf")
        #expect(draft.kind == .pdf)
        #expect(draft.data == Data("%PDF quote".utf8))

        claim.setAttachment(nil)
        try context.save()
        #expect(claim.attachmentDraft == nil)
        #expect(claim.attachmentData == nil)
    }
}
