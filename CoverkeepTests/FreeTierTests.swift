import Foundation
import Testing
import KeepCore
@testable import Coverkeep

@Suite("Free tier")
struct FreeTierTests {

    @Test("free holds exactly 10 items; the 11th needs Pro")
    func limit() {
        #expect(FreeTier.canCreateItem(existingItemCount: 0, isEntitled: false))
        #expect(FreeTier.canCreateItem(existingItemCount: 9, isEntitled: false))
        #expect(!FreeTier.canCreateItem(existingItemCount: 10, isEntitled: false))
        #expect(!FreeTier.canCreateItem(existingItemCount: 42, isEntitled: false))
    }

    @Test("entitlement removes the limit entirely")
    func entitled() {
        #expect(FreeTier.canCreateItem(existingItemCount: 10, isEntitled: true))
        #expect(FreeTier.canCreateItem(existingItemCount: 10_000, isEntitled: true))
    }

    @Test("product IDs use the personal namespace and match the StoreKit config")
    func productIDs() throws {
        #expect(CoverkeepProducts.annual == "com.birosbenedek.coverkeep.pro.annual")
        #expect(CoverkeepProducts.monthly == "com.birosbenedek.coverkeep.pro.monthly")
        #expect(CoverkeepProducts.lifetime == "com.birosbenedek.coverkeep.pro.lifetime")
        #expect(CoverkeepProducts.ids.all.count == 3)
        #expect(CoverkeepProducts.ids.displayOrder.first == CoverkeepProducts.annual)

        // Guard against the config and the code drifting apart: every ID in
        // code must appear verbatim in Coverkeep.storekit.
        let configURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Coverkeep.storekit")
        let config = try String(contentsOf: configURL, encoding: .utf8)
        for id in CoverkeepProducts.ids.all {
            #expect(config.contains("\"\(id)\""), "missing \(id) in Coverkeep.storekit")
        }
    }
}
