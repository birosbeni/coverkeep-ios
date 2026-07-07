import Foundation
import Testing
@testable import WarrantyRules

/// Calendar arithmetic edge cases. These use in-code rule sets so each case
/// isolates one duration; the bundled-content assertions live in the golden
/// expectation tables.
@Suite("Date math")
struct DateMathTests {

    private func endDate(
        purchase: (Int, Int, Int),
        duration: RuleDuration,
        timeZone: String = "Europe/Budapest"
    ) throws -> (year: Int, month: Int, day: Int) {
        let calendar = gregorian(timeZone)
        let engine = try testEngine(rules: [testRule(duration: duration)])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(purchase.0, purchase.1, purchase.2, in: calendar)
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        try #require(result.coverages.count == 1)
        return ymd(result.coverages[0].endDate, in: calendar)
    }

    // MARK: Month arithmetic and month-end clamping

    @Test("24 months from a mid-month purchase lands on the same day")
    func plainTwoYears() throws {
        let end = try endDate(purchase: (2026, 7, 7), duration: .months(24))
        #expect(end == (2028, 7, 7))
    }

    @Test("Jan 31 + 1 month clamps to Feb 28 in a common year")
    func januaryClampCommonYear() throws {
        let end = try endDate(purchase: (2026, 1, 31), duration: .months(1))
        #expect(end == (2026, 2, 28))
    }

    @Test("Jan 31 + 1 month clamps to Feb 29 in a leap year")
    func januaryClampLeapYear() throws {
        let end = try endDate(purchase: (2024, 1, 31), duration: .months(1))
        #expect(end == (2024, 2, 29))
    }

    @Test("a leap-day purchase + 24 months clamps to Feb 28")
    func leapDayPurchase() throws {
        let end = try endDate(purchase: (2024, 2, 29), duration: .months(24))
        #expect(end == (2026, 2, 28))
    }

    @Test("a leap-day purchase + 48 months lands back on Feb 29")
    func leapDayToLeapDay() throws {
        let end = try endDate(purchase: (2024, 2, 29), duration: .months(48))
        #expect(end == (2028, 2, 29))
    }

    @Test("Mar 31 + 1 month clamps to Apr 30")
    func thirtyDayClamp() throws {
        let end = try endDate(purchase: (2026, 3, 31), duration: .months(1))
        #expect(end == (2026, 4, 30))
    }

    @Test("Aug 31 + 24 months stays on Aug 31")
    func monthEndStable() throws {
        let end = try endDate(purchase: (2026, 8, 31), duration: .months(24))
        #expect(end == (2028, 8, 31))
    }

    // MARK: Day arithmetic across DST and year boundaries

    @Test("14 days across the spring-forward DST transition stays a civil 14 days")
    func dstSpringForward() throws {
        // Europe/Budapest springs forward on 2026-03-29.
        let end = try endDate(purchase: (2026, 3, 28), duration: .days(14))
        #expect(end == (2026, 4, 11))
    }

    @Test("14 days across the fall-back DST transition stays a civil 14 days")
    func dstFallBack() throws {
        // Europe/Budapest falls back on 2026-10-25.
        let end = try endDate(purchase: (2026, 10, 24), duration: .days(14))
        #expect(end == (2026, 11, 7))
    }

    @Test("14 days across the year boundary")
    func yearBoundary() throws {
        let end = try endDate(purchase: (2026, 12, 28), duration: .days(14))
        #expect(end == (2027, 1, 11))
    }

    @Test("14 days across a leap February")
    func leapFebruaryDays() throws {
        let end = try endDate(purchase: (2028, 2, 20), duration: .days(14))
        #expect(end == (2028, 3, 5))
    }

    // MARK: Burden of proof

    @Test("burden-of-proof end is computed from the same start, distinct from the coverage end")
    func burdenOfProof() throws {
        let calendar = gregorian()
        let engine = try testEngine(
            rules: [testRule(duration: .months(24), burdenOfProof: .months(12))]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 7, 7, in: calendar)
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        let coverage = try #require(result.coverages.first)
        let burdenEnd = try #require(coverage.burdenOfProofEndDate)
        #expect(ymd(burdenEnd, in: calendar) == (2027, 7, 7))
        #expect(ymd(coverage.endDate, in: calendar) == (2028, 7, 7))
        #expect(burdenEnd < coverage.endDate)
    }

    @Test("rules without a burden-of-proof period yield nil")
    func noBurdenOfProof() throws {
        let calendar = gregorian()
        let engine = try testEngine(rules: [testRule(duration: .days(14))])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 7, 7, in: calendar)
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)
        #expect(result.coverages.first?.burdenOfProofEndDate == nil)
    }

    // MARK: Normalization and stamping

    @Test("a mid-day purchase timestamp normalizes to civil start of day")
    func startOfDayNormalization() throws {
        let calendar = gregorian()
        let engine = try testEngine(rules: [testRule(duration: .months(24))])
        let noon = civilDate(2026, 7, 7, in: calendar).addingTimeInterval(12 * 3600 + 42 * 60)
        let context = PurchaseContext(countryCode: "EU", channel: .inStore, purchaseDate: noon)
        let result = engine.computeCoverages(for: context, calendar: calendar)
        let coverage = try #require(result.coverages.first)
        #expect(coverage.startDate == calendar.startOfDay(for: noon))
        #expect(ymd(coverage.endDate, in: calendar) == (2028, 7, 7))
    }

    @Test("every coverage is stamped with its producing rule and rule-set version")
    func versionStamping() throws {
        let calendar = gregorian()
        let engine = try testEngine(rules: [testRule(id: "test.stamp", duration: .months(24))])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 7, 7, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(coverage.ruleID == "test.stamp")
        #expect(coverage.ruleSetID == "EU")
        #expect(coverage.ruleSetVersion == "test-1")
        #expect(coverage.sources == [testSource])
    }
}
