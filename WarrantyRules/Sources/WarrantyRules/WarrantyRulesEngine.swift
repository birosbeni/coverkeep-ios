import Foundation

/// Computes a purchase's default coverages from the country rule sets.
/// Pure and deterministic: same context + same calendar → same civil dates,
/// regardless of device time zone. All date arithmetic goes through the
/// injected `Calendar`; there is no inline date math anywhere in the app.
public struct WarrantyRulesEngine: Sendable {
    public let store: RuleStore

    public init(store: RuleStore) {
        self.store = store
    }

    /// Convenience: an engine over the bundled, vetted rule sets.
    public static func bundled() throws -> WarrantyRulesEngine {
        WarrantyRulesEngine(store: try RuleStore.bundled())
    }

    public func computeCoverages(
        for context: PurchaseContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CoverageComputation {
        let resolution = store.ruleSet(forCountry: context.countryCode)
        let set = resolution.ruleSet
        var coverages: [ComputedCoverage] = []
        var skipped: [SkippedRule] = []

        for rule in set.rules {
            guard rule.channels.contains(context.channel) else { continue }

            let duration: RuleDuration
            if let fixed = rule.duration {
                duration = fixed
            } else if let bands = rule.priceBands {
                switch Self.bandDuration(for: context, in: bands) {
                case let .matched(banded):
                    duration = banded
                case let .skipped(reason):
                    skipped.append(
                        SkippedRule(
                            ruleID: rule.id,
                            kind: rule.kind,
                            reason: reason,
                            explanationKey: rule.explanationKey
                        )
                    )
                    continue
                }
            } else {
                // RuleStore validation guarantees exactly one of the two.
                preconditionFailure("Rule \(rule.id) passed validation without a duration source")
            }

            let clock = Self.clockStart(for: rule, context: context)
            let start = calendar.startOfDay(for: clock.date)
            let end = Self.date(byAdding: duration, to: start, calendar: calendar)
            let burdenEnd = rule.burdenOfProof.map {
                Self.date(byAdding: $0, to: start, calendar: calendar)
            }

            coverages.append(
                ComputedCoverage(
                    kind: rule.kind,
                    startDate: start,
                    endDate: end,
                    burdenOfProofEndDate: burdenEnd,
                    ruleID: rule.id,
                    ruleSetID: set.ruleSetID,
                    ruleSetVersion: set.ruleSetVersion,
                    explanationKey: rule.explanationKey,
                    sources: rule.sources,
                    clockStartAssumed: clock.assumed
                )
            )
        }

        return CoverageComputation(
            ruleSetID: set.ruleSetID,
            ruleSetVersion: set.ruleSetVersion,
            usedFallbackRuleSet: resolution.isFallback,
            coverages: coverages,
            skipped: skipped
        )
    }

    private enum BandResolution {
        case matched(RuleDuration)
        case skipped(SkippedRule.Reason)
    }

    private static func bandDuration(
        for context: PurchaseContext,
        in bands: PriceBands
    ) -> BandResolution {
        guard let price = context.price else {
            return .skipped(.priceUnknown)
        }
        guard let currency = context.currencyCode, currency == bands.currencyCode else {
            return .skipped(
                .currencyMismatch(
                    expected: bands.currencyCode,
                    actual: context.currencyCode ?? ""
                )
            )
        }
        guard let band = bands.band(containing: price) else {
            return .skipped(.priceOutsideBands)
        }
        return .matched(band.duration)
    }

    private static func clockStart(
        for rule: Rule,
        context: PurchaseContext
    ) -> (date: Date, assumed: Bool) {
        switch rule.clockStart {
        case .purchase:
            return (context.purchaseDate, false)
        case .delivery:
            if let delivery = context.deliveryDate {
                return (delivery, false)
            }
            return (context.purchaseDate, true)
        }
    }

    private static func date(
        byAdding duration: RuleDuration,
        to start: Date,
        calendar: Calendar
    ) -> Date {
        let result: Date?
        if let months = duration.months {
            result = calendar.date(byAdding: .month, value: months, to: start)
        } else if let days = duration.days {
            result = calendar.date(byAdding: .day, value: days, to: start)
        } else {
            // RuleStore validation guarantees exactly one positive unit.
            preconditionFailure("Duration passed validation with no unit")
        }
        guard let end = result else {
            // Gregorian component addition to a valid date cannot fail; if it
            // ever does, corrupt output would be worse than a crash.
            preconditionFailure("Calendar failed to add \(duration) to \(start)")
        }
        return calendar.startOfDay(for: end)
    }
}
