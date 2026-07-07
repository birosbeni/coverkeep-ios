import Foundation
@testable import WarrantyRules

/// A Gregorian calendar pinned to a time zone, so tests state their frame of
/// reference explicitly.
func gregorian(_ timeZoneID: String = "Europe/Budapest") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    guard let timeZone = TimeZone(identifier: timeZoneID) else {
        preconditionFailure("Unknown time zone \(timeZoneID)")
    }
    calendar.timeZone = timeZone
    return calendar
}

/// A civil date built in the given calendar.
func civilDate(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        preconditionFailure("Invalid civil date \(year)-\(month)-\(day)")
    }
    return date
}

/// The (year, month, day) of a date, read back in the same calendar.
func ymd(_ date: Date, in calendar: Calendar) -> (year: Int, month: Int, day: Int) {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return (components.year!, components.month!, components.day!)
}

/// A minimal valid rule set for engine-mechanics tests. Uses the fallback ID
/// so a single-set store passes validation.
func testRuleSet(rules: [Rule]) -> RuleSet {
    RuleSet(
        schemaVersion: 1,
        ruleSetID: RuleStore.fallbackRuleSetID,
        ruleSetVersion: "test-1",
        contentVerified: "2026-07-07",
        rules: rules
    )
}

let testSource = RuleSource(title: "Test source", url: "https://example.org/law")

func testRule(
    id: String = "test.rule",
    kind: CoverageKind = .legalGuarantee,
    channels: [PurchaseChannel] = [.inStore, .online],
    clockStart: ClockStart = .purchase,
    duration: RuleDuration? = nil,
    priceBands: PriceBands? = nil,
    burdenOfProof: RuleDuration? = nil
) -> Rule {
    Rule(
        id: id,
        kind: kind,
        channels: channels,
        clockStart: clockStart,
        duration: duration,
        priceBands: priceBands,
        burdenOfProof: burdenOfProof,
        explanationKey: "rule.test",
        comment: nil,
        sources: [testSource]
    )
}

func testEngine(rules: [Rule]) throws -> WarrantyRulesEngine {
    WarrantyRulesEngine(store: try RuleStore(ruleSets: [testRuleSet(rules: rules)]))
}
