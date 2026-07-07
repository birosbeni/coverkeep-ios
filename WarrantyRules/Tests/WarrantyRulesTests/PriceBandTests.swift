import Foundation
import Testing
@testable import WarrantyRules

/// Boundary behavior of the price-banded Hungarian jótállás against the
/// BUNDLED HU rule set — the verbatim statutory thresholds of
/// 151/2003. Korm. r. 2. § (1): ≥ 10 000 Ft and ≤ 250 000 Ft → 2 years,
/// > 250 000 Ft → 3 years, below 10 000 Ft → no jótállás.
@Suite("Hungarian jótállás price bands")
struct PriceBandTests {

    private func jotallas(
        price: Decimal?,
        currency: String? = "HUF"
    ) throws -> (coverage: ComputedCoverage?, skip: SkippedRule?) {
        let calendar = gregorian()
        let engine = try WarrantyRulesEngine.bundled()
        let context = PurchaseContext(
            countryCode: "HU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 7, 7, in: calendar),
            deliveryDate: civilDate(2026, 7, 7, in: calendar),
            price: price,
            currencyCode: currency
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        return (
            result.coverages.first { $0.kind == .commercialWarranty },
            result.skipped.first { $0.kind == .commercialWarranty }
        )
    }

    private func months(of coverage: ComputedCoverage) -> Int {
        let calendar = gregorian()
        let components = calendar.dateComponents(
            [.month], from: coverage.startDate, to: coverage.endDate
        )
        return components.month!
    }

    @Test("below 10 000 Ft there is no jótállás", arguments: ["9999", "9999.99", "1"])
    func belowFloor(price: String) throws {
        let result = try jotallas(price: Decimal(string: price)!)
        #expect(result.coverage == nil)
        #expect(result.skip?.reason == .priceOutsideBands)
    }

    @Test("exactly 10 000 Ft ('elérő' — inclusive) → 2 years")
    func floorInclusive() throws {
        let coverage = try #require(try jotallas(price: 10_000).coverage)
        #expect(months(of: coverage) == 24)
    }

    @Test("mid-band 100 000 Ft → 2 years (the old 1-year tier is gone)")
    func midBand() throws {
        let coverage = try #require(try jotallas(price: 100_000).coverage)
        #expect(months(of: coverage) == 24)
    }

    @Test("exactly 250 000 Ft ('meg nem haladó' — inclusive) → 2 years")
    func upperBoundInclusive() throws {
        let coverage = try #require(try jotallas(price: 250_000).coverage)
        #expect(months(of: coverage) == 24)
    }

    @Test("just above 250 000 Ft ('felett' — exclusive) → 3 years")
    func aboveThreshold() throws {
        let justAbove = try #require(Decimal(string: "250000.01"))
        let coverage = try #require(try jotallas(price: justAbove).coverage)
        #expect(months(of: coverage) == 36)

        let coverage251k = try #require(try jotallas(price: 250_001).coverage)
        #expect(months(of: coverage251k) == 36)
    }

    @Test("a missing price is reported, not guessed")
    func missingPrice() throws {
        let result = try jotallas(price: nil)
        #expect(result.coverage == nil)
        #expect(result.skip?.reason == .priceUnknown)
    }

    @Test("a non-HUF price is reported as a currency mismatch, not converted")
    func currencyMismatch() throws {
        let result = try jotallas(price: 400, currency: "EUR")
        #expect(result.coverage == nil)
        #expect(result.skip?.reason == .currencyMismatch(expected: "HUF", actual: "EUR"))
    }

    @Test("the jótállás never fires outside Hungary's rule set")
    func onlyInHungary() throws {
        let calendar = gregorian()
        let engine = try WarrantyRulesEngine.bundled()
        for country in ["DE", "AT", "FR"] {
            let context = PurchaseContext(
                countryCode: country,
                channel: .inStore,
                purchaseDate: civilDate(2026, 7, 7, in: calendar),
                price: 300_000,
                currencyCode: "HUF"
            )
            let result = engine.computeCoverages(for: context, calendar: calendar)
            #expect(
                !result.coverages.contains { $0.kind == .commercialWarranty },
                "unexpected jótállás in \(country)"
            )
        }
    }
}
