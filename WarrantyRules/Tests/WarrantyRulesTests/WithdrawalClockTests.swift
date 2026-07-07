import Foundation
import Testing
@testable import WarrantyRules

/// The withdrawal (and legal-guarantee) clock legally starts at DELIVERY.
/// When only the purchase date is known the engine must fall back to it and
/// say so, never silently pretend.
@Suite("Delivery clock")
struct WithdrawalClockTests {

    private func deliveryRule() -> Rule {
        testRule(
            id: "test.withdrawal",
            kind: .withdrawal,
            channels: [.online],
            clockStart: .delivery,
            duration: .days(14)
        )
    }

    @Test("with a delivery date, the clock starts there and nothing is assumed")
    func deliveryDateKnown() throws {
        let calendar = gregorian()
        let engine = try testEngine(rules: [deliveryRule()])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .online,
            purchaseDate: civilDate(2026, 7, 1, in: calendar),
            deliveryDate: civilDate(2026, 7, 7, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.startDate, in: calendar) == (2026, 7, 7))
        #expect(ymd(coverage.endDate, in: calendar) == (2026, 7, 21))
        #expect(!coverage.clockStartAssumed)
    }

    @Test("without a delivery date, the clock falls back to purchase and is flagged")
    func deliveryDateMissing() throws {
        let calendar = gregorian()
        let engine = try testEngine(rules: [deliveryRule()])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .online,
            purchaseDate: civilDate(2026, 7, 1, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.startDate, in: calendar) == (2026, 7, 1))
        #expect(ymd(coverage.endDate, in: calendar) == (2026, 7, 15))
        #expect(coverage.clockStartAssumed)
    }

    @Test("purchase-clock rules ignore the delivery date and are never flagged")
    func purchaseClockIgnoresDelivery() throws {
        let calendar = gregorian()
        let engine = try testEngine(
            rules: [testRule(clockStart: .purchase, duration: .months(24))]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .online,
            purchaseDate: civilDate(2026, 7, 1, in: calendar),
            deliveryDate: civilDate(2026, 7, 7, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.startDate, in: calendar) == (2026, 7, 1))
        #expect(!coverage.clockStartAssumed)
    }

    @Test("in-store purchases get no withdrawal coverage at all")
    func inStoreHasNoWithdrawal() throws {
        let calendar = gregorian()
        let engine = try testEngine(
            rules: [
                testRule(id: "test.lg", kind: .legalGuarantee, duration: .months(24)),
                deliveryRule(),
            ]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 7, 1, in: calendar)
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        #expect(result.coverages.map(\.kind) == [.legalGuarantee])
        // Channel mismatch is normal filtering, not a reportable skip.
        #expect(result.skipped.isEmpty)
    }

    @Test("online purchases get both the guarantee and the withdrawal window")
    func onlineGetsBoth() throws {
        let calendar = gregorian()
        let engine = try testEngine(
            rules: [
                testRule(id: "test.lg", kind: .legalGuarantee, duration: .months(24)),
                deliveryRule(),
            ]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .online,
            purchaseDate: civilDate(2026, 7, 1, in: calendar)
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        #expect(result.coverages.map(\.kind) == [.legalGuarantee, .withdrawal])
    }
}
