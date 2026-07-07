import Foundation
import Testing
@testable import WarrantyRules

/// Golden expectation tables against the BUNDLED, OWNER-VETTED rule sets
/// (vetting completed 2026-07-07). Every case is a human-checkable legal
/// assertion: given this purchase, an EU consumer holds exactly these
/// rights until exactly these dates.
///
/// The rule files are vetted-frozen — if one of these tests fails after a
/// rule-file edit, the edit needs owner sign-off, not a test fix.
@Suite("Golden expectations (vetted content)")
struct GoldenExpectationTests {

    struct YMD: Equatable, CustomStringConvertible {
        let year: Int, month: Int, day: Int
        init(_ year: Int, _ month: Int, _ day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }
        var description: String {
            String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    struct ExpectedCoverage {
        let ruleID: String
        let kind: CoverageKind
        let start: YMD
        let end: YMD
        let burdenOfProofEnd: YMD?
        let clockStartAssumed: Bool

        init(
            _ ruleID: String,
            _ kind: CoverageKind,
            start: YMD,
            end: YMD,
            burdenOfProofEnd: YMD? = nil,
            clockStartAssumed: Bool = false
        ) {
            self.ruleID = ruleID
            self.kind = kind
            self.start = start
            self.end = end
            self.burdenOfProofEnd = burdenOfProofEnd
            self.clockStartAssumed = clockStartAssumed
        }
    }

    struct GoldenCase: CustomStringConvertible {
        let label: String
        let countryCode: String
        let channel: PurchaseChannel
        let purchase: YMD
        let delivery: YMD?
        let price: Decimal?
        let currency: String?
        let expectRuleSetID: String
        let expectFallback: Bool
        let expectCoverages: [ExpectedCoverage]
        let expectSkippedRuleIDs: [String]

        var description: String { label }
    }

    static let cases: [GoldenCase] = [

        // ─── Hungary ────────────────────────────────────────────────────

        GoldenCase(
            label: "HU online laptop, 649 990 Ft, delivered 3 days after purchase",
            countryCode: "HU", channel: .online,
            purchase: YMD(2026, 7, 7), delivery: YMD(2026, 7, 10),
            price: 649_990, currency: "HUF",
            expectRuleSetID: "HU", expectFallback: false,
            expectCoverages: [
                // Kellékszavatosság: 2 years from delivery, defect presumed
                // for 1 year (373/2021. Korm. r. 11. §, Ptk. 6:163. §).
                ExpectedCoverage(
                    "hu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 7, 10), end: YMD(2028, 7, 10),
                    burdenOfProofEnd: YMD(2027, 7, 10)
                ),
                // Jótállás: above 250 000 Ft → 3 years from handover
                // (151/2003. Korm. r. 2. §, in-force two-tier text).
                ExpectedCoverage(
                    "hu.mandatory-warranty", .commercialWarranty,
                    start: YMD(2026, 7, 10), end: YMD(2029, 7, 10)
                ),
                // Elállás: 14 days from receipt (45/2014. Korm. r. 20. §).
                ExpectedCoverage(
                    "hu.withdrawal", .withdrawal,
                    start: YMD(2026, 7, 10), end: YMD(2026, 7, 24)
                ),
            ],
            expectSkippedRuleIDs: []
        ),

        GoldenCase(
            label: "HU in-store vacuum, 150 000 Ft, no delivery date recorded",
            countryCode: "HU", channel: .inStore,
            purchase: YMD(2026, 7, 7), delivery: nil,
            price: 150_000, currency: "HUF",
            expectRuleSetID: "HU", expectFallback: false,
            expectCoverages: [
                // Delivery clock falls back to the purchase date, flagged.
                ExpectedCoverage(
                    "hu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 7, 7), end: YMD(2028, 7, 7),
                    burdenOfProofEnd: YMD(2027, 7, 7),
                    clockStartAssumed: true
                ),
                // Mid-band price → 2 years (the old 1-year tier is GONE).
                ExpectedCoverage(
                    "hu.mandatory-warranty", .commercialWarranty,
                    start: YMD(2026, 7, 7), end: YMD(2028, 7, 7),
                    clockStartAssumed: true
                ),
                // No withdrawal in-store.
            ],
            expectSkippedRuleIDs: []
        ),

        GoldenCase(
            label: "HU online phone case, 9 000 Ft — below the jótállás floor",
            countryCode: "HU", channel: .online,
            purchase: YMD(2026, 7, 7), delivery: YMD(2026, 7, 9),
            price: 9_000, currency: "HUF",
            expectRuleSetID: "HU", expectFallback: false,
            expectCoverages: [
                ExpectedCoverage(
                    "hu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 7, 9), end: YMD(2028, 7, 9),
                    burdenOfProofEnd: YMD(2027, 7, 9)
                ),
                ExpectedCoverage(
                    "hu.withdrawal", .withdrawal,
                    start: YMD(2026, 7, 9), end: YMD(2026, 7, 23)
                ),
            ],
            // No jótállás below 10 000 Ft — reported, not silently dropped.
            expectSkippedRuleIDs: ["hu.mandatory-warranty"]
        ),

        GoldenCase(
            label: "HU in-store TV bought in euros — jótállás needs a HUF price",
            countryCode: "HU", channel: .inStore,
            purchase: YMD(2026, 7, 7), delivery: YMD(2026, 7, 7),
            price: 1_200, currency: "EUR",
            expectRuleSetID: "HU", expectFallback: false,
            expectCoverages: [
                ExpectedCoverage(
                    "hu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 7, 7), end: YMD(2028, 7, 7),
                    burdenOfProofEnd: YMD(2027, 7, 7)
                ),
            ],
            expectSkippedRuleIDs: ["hu.mandatory-warranty"]
        ),

        // ─── Germany ────────────────────────────────────────────────────

        GoldenCase(
            label: "DE online monitor delivered on leap day 2028",
            countryCode: "DE", channel: .online,
            purchase: YMD(2028, 2, 25), delivery: YMD(2028, 2, 29),
            price: Decimal(string: "349.99"), currency: "EUR",
            expectRuleSetID: "DE", expectFallback: false,
            expectCoverages: [
                // BGB § 438: two years from Ablieferung; leap-day start
                // clamps to Feb 28 in the common year 2030. § 477: one-year
                // presumption clamps the same way in 2029.
                ExpectedCoverage(
                    "de.legal-guarantee", .legalGuarantee,
                    start: YMD(2028, 2, 29), end: YMD(2030, 2, 28),
                    burdenOfProofEnd: YMD(2029, 2, 28)
                ),
                // Widerruf: 14 days from receipt crosses into March.
                ExpectedCoverage(
                    "de.withdrawal", .withdrawal,
                    start: YMD(2028, 2, 29), end: YMD(2028, 3, 14)
                ),
            ],
            expectSkippedRuleIDs: []
        ),

        GoldenCase(
            label: "DE in-store drill — guarantee only, price irrelevant",
            countryCode: "DE", channel: .inStore,
            purchase: YMD(2026, 8, 31), delivery: nil,
            price: nil, currency: nil,
            expectRuleSetID: "DE", expectFallback: false,
            expectCoverages: [
                ExpectedCoverage(
                    "de.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 8, 31), end: YMD(2028, 8, 31),
                    burdenOfProofEnd: YMD(2027, 8, 31),
                    clockStartAssumed: true
                ),
            ],
            expectSkippedRuleIDs: []
        ),

        // ─── Austria ────────────────────────────────────────────────────

        GoldenCase(
            label: "AT online e-bike delivered end of January",
            countryCode: "AT", channel: .online,
            purchase: YMD(2026, 1, 28), delivery: YMD(2026, 1, 31),
            price: Decimal(string: "2499.00"), currency: "EUR",
            expectRuleSetID: "AT", expectFallback: false,
            expectCoverages: [
                // VGG § 10: two years from Übergabe; § 11: one-year
                // Vermutungsfrist — Jan 31 start clamps neither year.
                ExpectedCoverage(
                    "at.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 1, 31), end: YMD(2028, 1, 31),
                    burdenOfProofEnd: YMD(2027, 1, 31)
                ),
                // FAGG § 11: 14 days from possession crosses into February.
                ExpectedCoverage(
                    "at.withdrawal", .withdrawal,
                    start: YMD(2026, 1, 31), end: YMD(2026, 2, 14)
                ),
            ],
            expectSkippedRuleIDs: []
        ),

        // ─── EU fallback ────────────────────────────────────────────────

        GoldenCase(
            label: "FR online purchase falls back to the EU minimum set, flagged",
            countryCode: "FR", channel: .online,
            purchase: YMD(2026, 12, 24), delivery: YMD(2026, 12, 28),
            price: Decimal(string: "89.90"), currency: "EUR",
            expectRuleSetID: "EU", expectFallback: true,
            expectCoverages: [
                ExpectedCoverage(
                    "eu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 12, 28), end: YMD(2028, 12, 28),
                    burdenOfProofEnd: YMD(2027, 12, 28)
                ),
                // 14 days from delivery crosses the year boundary.
                ExpectedCoverage(
                    "eu.withdrawal", .withdrawal,
                    start: YMD(2026, 12, 28), end: YMD(2027, 1, 11)
                ),
            ],
            expectSkippedRuleIDs: []
        ),

        GoldenCase(
            label: "unknown country in-store, no extras — EU guarantee only",
            countryCode: "XX", channel: .inStore,
            purchase: YMD(2026, 7, 7), delivery: nil,
            price: nil, currency: nil,
            expectRuleSetID: "EU", expectFallback: true,
            expectCoverages: [
                ExpectedCoverage(
                    "eu.legal-guarantee", .legalGuarantee,
                    start: YMD(2026, 7, 7), end: YMD(2028, 7, 7),
                    burdenOfProofEnd: YMD(2027, 7, 7),
                    clockStartAssumed: true
                ),
            ],
            expectSkippedRuleIDs: []
        ),
    ]

    @Test("golden case", arguments: cases)
    func golden(testCase: GoldenCase) throws {
        let calendar = gregorian("Europe/Budapest")

        func date(_ ymdValue: YMD) -> Date {
            civilDate(ymdValue.year, ymdValue.month, ymdValue.day, in: calendar)
        }
        func asYMD(_ dateValue: Date) -> YMD {
            let components = ymd(dateValue, in: calendar)
            return YMD(components.year, components.month, components.day)
        }

        let engine = try WarrantyRulesEngine.bundled()
        let context = PurchaseContext(
            countryCode: testCase.countryCode,
            channel: testCase.channel,
            purchaseDate: date(testCase.purchase),
            deliveryDate: testCase.delivery.map(date),
            price: testCase.price,
            currencyCode: testCase.currency
        )
        let result = engine.computeCoverages(for: context, calendar: calendar)

        #expect(result.ruleSetID == testCase.expectRuleSetID)
        #expect(result.usedFallbackRuleSet == testCase.expectFallback)
        #expect(result.skipped.map(\.ruleID) == testCase.expectSkippedRuleIDs)

        try #require(result.coverages.count == testCase.expectCoverages.count)
        for (actual, expected) in zip(result.coverages, testCase.expectCoverages) {
            #expect(actual.ruleID == expected.ruleID)
            #expect(actual.kind == expected.kind)
            #expect(asYMD(actual.startDate) == expected.start, "start of \(expected.ruleID)")
            #expect(asYMD(actual.endDate) == expected.end, "end of \(expected.ruleID)")
            #expect(
                actual.burdenOfProofEndDate.map(asYMD) == expected.burdenOfProofEnd,
                "burden of proof of \(expected.ruleID)"
            )
            #expect(actual.clockStartAssumed == expected.clockStartAssumed)
        }
    }
}
