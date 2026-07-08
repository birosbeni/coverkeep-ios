import Foundation
import SwiftData
import Testing
import WarrantyRules
@testable import Coverkeep

@Suite("SwiftData model smoke tests")
@MainActor
struct ModelSmokeTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
    }

    @Test("the full object graph round-trips through an in-memory store")
    func roundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let item = Item(
            name: "Laptop",
            category: .electronics,
            brand: "Apple",
            priceAmount: Decimal(string: "649990"),
            currencyCode: "HUF",
            seller: "iStore Budapest",
            channel: .online,
            countryCode: "HU"
        )
        context.insert(item)

        let receipt = Receipt(originalKept: true)
        receipt.item = item
        context.insert(receipt)

        let coverage = Coverage(kind: .extendedWarranty, startDate: .now, endDate: .now)
        coverage.item = item
        context.insert(coverage)

        let event = Event(kind: .claim, note: "Screen flicker reported")
        event.item = item
        context.insert(event)

        try context.save()

        let items = try context.fetch(FetchDescriptor<Item>())
        let fetched = try #require(items.first)
        #expect(items.count == 1)
        #expect(fetched.receipts?.count == 1)
        #expect(fetched.coverages?.count == 1)
        #expect(fetched.events?.count == 1)
        #expect(fetched.category == .electronics)
        #expect(fetched.channel == .online)
    }

    @Test("deleting an item cascades to its receipts, coverages, and events")
    func cascadeDelete() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let item = Item(name: "Vacuum")
        context.insert(item)
        let receipt = Receipt()
        receipt.item = item
        context.insert(receipt)
        try context.save()

        context.delete(item)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Receipt>()).isEmpty)
    }

    @Test("engine output maps into Coverage with full provenance and the right reminder lead")
    func computedCoverageMapping() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        let purchase = calendar.date(from: DateComponents(year: 2026, month: 7, day: 7))!

        let engine = try WarrantyRulesEngine.bundled()
        let context = PurchaseContext(
            countryCode: "HU",
            channel: .online,
            purchaseDate: purchase,
            deliveryDate: purchase
        )
        let computation = engine.computeCoverages(for: context, calendar: calendar)

        let withdrawal = try #require(
            computation.coverages.first { $0.kind == .withdrawal }
        )
        let mapped = Coverage(computed: withdrawal)
        #expect(mapped.kind == .withdrawal)
        #expect(mapped.source == .computedFromRules)
        #expect(mapped.reminderLeadDays == 3)
        #expect(mapped.ruleID == withdrawal.ruleID)
        #expect(mapped.ruleSetID == "HU")
        #expect(mapped.ruleSetVersion == withdrawal.ruleSetVersion)
        #expect(!mapped.clockStartAssumed)

        let guarantee = try #require(
            computation.coverages.first { $0.kind == .legalGuarantee }
        )
        let mappedGuarantee = Coverage(computed: guarantee)
        #expect(mappedGuarantee.reminderLeadDays == 30)
        #expect(mappedGuarantee.burdenOfProofEndDate == guarantee.burdenOfProofEndDate)
    }
}
