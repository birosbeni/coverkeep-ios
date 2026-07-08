import Foundation
import SwiftData
import Testing
@testable import Coverkeep

@Suite("Item search")
@MainActor
struct ItemSearchTests {

    private func makeItems() throws -> (ModelContext, [Item]) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let vacuum = Item(
            name: "Porszívó", category: .appliance, brand: "Dyson",
            seller: "Media Markt", notes: "black friday deal"
        )
        let drill = Item(
            name: "Hammer drill", category: .tool, brand: "Bosch",
            modelName: "GBH 2-26", seller: "OBI"
        )
        let laptop = Item(name: "Laptop", category: .electronics, brand: "Apple")
        for item in [vacuum, drill, laptop] {
            context.insert(item)
        }
        return (context, [vacuum, drill, laptop])
    }

    @Test("finds the vacuum by name, diacritic-insensitively")
    func nameAndDiacritics() throws {
        let (_, items) = try makeItems()
        #expect(ItemSearch.filter(items, query: "porszivo").map(\.name) == ["Porszívó"])
        #expect(ItemSearch.filter(items, query: "PORSZÍVÓ").map(\.name) == ["Porszívó"])
    }

    @Test("finds by brand, seller, model, and notes")
    func otherFields() throws {
        let (_, items) = try makeItems()
        #expect(ItemSearch.filter(items, query: "dyson").map(\.name) == ["Porszívó"])
        #expect(ItemSearch.filter(items, query: "obi").map(\.name) == ["Hammer drill"])
        #expect(ItemSearch.filter(items, query: "gbh 2-26").map(\.name) == ["Hammer drill"])
        #expect(ItemSearch.filter(items, query: "black friday").map(\.name) == ["Porszívó"])
    }

    @Test("multiple terms all have to match, across different fields")
    func multiTerm() throws {
        let (_, items) = try makeItems()
        #expect(ItemSearch.filter(items, query: "bosch drill").map(\.name) == ["Hammer drill"])
        #expect(ItemSearch.filter(items, query: "bosch laptop").isEmpty)
    }

    @Test("category filter narrows results and combines with text")
    func categoryFilter() throws {
        let (_, items) = try makeItems()
        #expect(ItemSearch.filter(items, query: "", category: .tool).map(\.name) == ["Hammer drill"])
        #expect(ItemSearch.filter(items, query: "bosch", category: .tool).count == 1)
        #expect(ItemSearch.filter(items, query: "bosch", category: .electronics).isEmpty)
    }

    @Test("empty and whitespace queries return everything")
    func emptyQuery() throws {
        let (_, items) = try makeItems()
        #expect(ItemSearch.filter(items, query: "").count == 3)
        #expect(ItemSearch.filter(items, query: "   ").count == 3)
    }
}
