import Foundation
import Testing
@testable import WarrantyRules

/// The engine must yield the same CIVIL dates whatever time zone the device
/// calendar carries — a Budapest purchase reviewed on holiday in Los Angeles
/// must not shift a deadline by a day.
@Suite("Time zone determinism")
struct TimezoneDeterminismTests {

    private static let timeZones = [
        "UTC",
        "Europe/Budapest",
        "Pacific/Kiritimati",     // UTC+14, the earliest civil day on Earth
        "America/Los_Angeles",    // far west, with its own DST schedule
    ]

    @Test("24-month end dates agree across time zones", arguments: timeZones)
    func monthsAgree(timeZoneID: String) throws {
        let calendar = gregorian(timeZoneID)
        let engine = try testEngine(
            rules: [testRule(duration: .months(24), burdenOfProof: .months(12))]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2026, 1, 31, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.endDate, in: calendar) == (2028, 1, 31))
        let burdenEnd = try #require(coverage.burdenOfProofEndDate)
        #expect(ymd(burdenEnd, in: calendar) == (2027, 1, 31))
    }

    @Test("14-day windows agree across time zones", arguments: timeZones)
    func daysAgree(timeZoneID: String) throws {
        let calendar = gregorian(timeZoneID)
        let engine = try testEngine(
            rules: [testRule(kind: .withdrawal, channels: [.online], duration: .days(14))]
        )
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .online,
            purchaseDate: civilDate(2026, 12, 28, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.endDate, in: calendar) == (2027, 1, 11))
    }

    @Test("leap-day clamping agrees across time zones", arguments: timeZones)
    func leapDayAgrees(timeZoneID: String) throws {
        let calendar = gregorian(timeZoneID)
        let engine = try testEngine(rules: [testRule(duration: .months(24))])
        let context = PurchaseContext(
            countryCode: "EU",
            channel: .inStore,
            purchaseDate: civilDate(2024, 2, 29, in: calendar)
        )
        let coverage = try #require(
            engine.computeCoverages(for: context, calendar: calendar).coverages.first
        )
        #expect(ymd(coverage.endDate, in: calendar) == (2026, 2, 28))
    }
}
