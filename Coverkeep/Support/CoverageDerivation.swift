import Foundation
import SwiftData
import WarrantyRules

/// Glue between the pure engine and the data model: builds the engine input
/// from an `Item` and keeps its computed coverages in sync when the fields
/// they derive from change.
enum CoverageDerivation {

    static func purchaseContext(for item: Item) -> PurchaseContext {
        PurchaseContext(
            countryCode: item.countryCode,
            channel: item.channel,
            purchaseDate: item.purchaseDate,
            deliveryDate: item.deliveryDate,
            price: item.priceAmount,
            currencyCode: item.currencyCode
        )
    }

    /// Recomputes the item's engine-derived coverages after its purchase
    /// facts changed. Manual coverages are untouched; reminder-lead
    /// overrides on computed coverages survive, matched by rule ID.
    @discardableResult
    static func regenerateComputedCoverages(
        for item: Item,
        engine: WarrantyRulesEngine,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> CoverageComputation {
        let computation = engine.computeCoverages(
            for: purchaseContext(for: item), calendar: calendar
        )

        var leadOverrides: [String: Int] = [:]
        for coverage in item.coverages ?? [] where coverage.source == .computedFromRules {
            if let ruleID = coverage.ruleID,
                coverage.reminderLeadDays != Coverage.defaultReminderLeadDays(for: coverage.kind)
            {
                leadOverrides[ruleID] = coverage.reminderLeadDays
            }
            context.delete(coverage)
        }

        for computed in computation.coverages {
            let coverage = Coverage(computed: computed)
            if let override = leadOverrides[computed.ruleID] {
                coverage.reminderLeadDays = override
            }
            coverage.item = item
            context.insert(coverage)
        }
        return computation
    }
}
