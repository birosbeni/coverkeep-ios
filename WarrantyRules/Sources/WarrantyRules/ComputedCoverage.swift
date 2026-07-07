import Foundation

/// One protection the engine derived from a rule. Dates are civil dates
/// normalized to the start of day in the calendar the engine was given.
///
/// `endDate` is the LAST day the right can still be exercised (inclusive):
/// goods received on 7 July with a 14-day withdrawal can be returned through
/// 21 July; a 24-month guarantee started 7 July 2026 runs through
/// 7 July 2028.
public struct ComputedCoverage: Sendable, Equatable {
    public let kind: CoverageKind
    public let startDate: Date
    public let endDate: Date
    /// Until when a defect is presumed to have existed at delivery
    /// (reversed burden of proof), when the rule defines one.
    public let burdenOfProofEndDate: Date?
    public let ruleID: String
    public let ruleSetID: String
    public let ruleSetVersion: String
    public let explanationKey: String
    public let sources: [RuleSource]
    /// True when the rule's clock starts at delivery but only the purchase
    /// date was available — the UI must invite the user to correct the
    /// delivery date.
    public let clockStartAssumed: Bool
}

/// A price-banded rule the engine could not apply. Surfaced instead of
/// silently dropped so the UI can explain why (e.g. "enter the price to see
/// your jótállás").
public struct SkippedRule: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        /// The rule needs a price but the context has none.
        case priceUnknown
        /// The price is in a different currency than the rule's bands.
        case currencyMismatch(expected: String, actual: String)
        /// The price falls outside every band — the protection simply does
        /// not attach (e.g. no jótállás below 10 000 Ft).
        case priceOutsideBands
    }

    public let ruleID: String
    public let kind: CoverageKind
    public let reason: Reason
    public let explanationKey: String
}

/// The full result of one computation: which rule set answered (and whether
/// it was the EU fallback), the coverages, and any rules that could not be
/// applied.
public struct CoverageComputation: Sendable, Equatable {
    public let ruleSetID: String
    public let ruleSetVersion: String
    /// True when the country had no vetted rule set and the EU minimums
    /// were used — the UI must say so.
    public let usedFallbackRuleSet: Bool
    public let coverages: [ComputedCoverage]
    public let skipped: [SkippedRule]
}
