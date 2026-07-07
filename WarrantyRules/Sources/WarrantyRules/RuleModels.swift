import Foundation

/// One country's consumer-rights rules, decoded from a bundled, versioned
/// JSON file. Rules are DATA, not code: durations, burden-of-proof periods,
/// and official source links all live in the file so they can be vetted and
/// updated without touching the engine.
public struct RuleSet: Codable, Sendable, Equatable {
    /// Bumped only when the JSON structure changes incompatibly.
    public let schemaVersion: Int
    /// ISO 3166-1 alpha-2 country code, or "EU" for the union-wide fallback.
    public let ruleSetID: String
    /// Content revision, stamped onto every computed coverage so stored
    /// coverages never silently change when a rule file is updated.
    public let ruleSetVersion: String
    /// ISO date (yyyy-MM-dd) the content was last checked against the live
    /// official text (njt.hu, gesetze-im-internet.de, ris.bka.gv.at, EUR-Lex).
    public let contentVerified: String
    public let rules: [Rule]

    public init(
        schemaVersion: Int,
        ruleSetID: String,
        ruleSetVersion: String,
        contentVerified: String,
        rules: [Rule]
    ) {
        self.schemaVersion = schemaVersion
        self.ruleSetID = ruleSetID
        self.ruleSetVersion = ruleSetVersion
        self.contentVerified = contentVerified
        self.rules = rules
    }
}

/// A single protection rule. Exactly one of `duration` or `priceBands`
/// supplies the coverage length (enforced by `RuleStore` validation).
public struct Rule: Codable, Sendable, Equatable {
    public let id: String
    public let kind: CoverageKind
    /// Channels the rule attaches to; e.g. withdrawal is online-only.
    public let channels: [PurchaseChannel]
    /// Which date starts the coverage clock. EU law starts both the legal
    /// guarantee and the withdrawal window at DELIVERY, not purchase.
    public let clockStart: ClockStart
    public let duration: RuleDuration?
    /// Price-tiered durations (e.g. the Hungarian jótállás). Requires the
    /// purchase price in the band currency; otherwise the rule is reported
    /// as skipped rather than guessed.
    public let priceBands: PriceBands?
    /// How long after the clock start a defect is presumed to have existed
    /// at delivery (reversed burden of proof).
    public let burdenOfProof: RuleDuration?
    /// String Catalog key for the plain-language explanation; copy lives in
    /// the app so this package stays UI- and locale-free.
    public let explanationKey: String
    /// Maintainer note: verification trail, verbatim quotes, and documented
    /// simplifications. Never shown to users.
    public let comment: String?
    /// Official sources; at least one, all http(s). The app links these next
    /// to every computed coverage.
    public let sources: [RuleSource]

    public init(
        id: String,
        kind: CoverageKind,
        channels: [PurchaseChannel],
        clockStart: ClockStart,
        duration: RuleDuration? = nil,
        priceBands: PriceBands? = nil,
        burdenOfProof: RuleDuration? = nil,
        explanationKey: String,
        comment: String? = nil,
        sources: [RuleSource]
    ) {
        self.id = id
        self.kind = kind
        self.channels = channels
        self.clockStart = clockStart
        self.duration = duration
        self.priceBands = priceBands
        self.burdenOfProof = burdenOfProof
        self.explanationKey = explanationKey
        self.comment = comment
        self.sources = sources
    }
}

/// Which event starts a coverage clock.
public enum ClockStart: String, Codable, Sendable {
    case purchase
    case delivery
}

/// A coverage length in exactly one unit. Calendar arithmetic happens in the
/// engine via `Calendar` — never inline date math.
public struct RuleDuration: Codable, Sendable, Equatable {
    public let months: Int?
    public let days: Int?

    public static func months(_ value: Int) -> RuleDuration {
        RuleDuration(months: value, days: nil)
    }

    public static func days(_ value: Int) -> RuleDuration {
        RuleDuration(months: nil, days: value)
    }

    public init(months: Int?, days: Int?) {
        self.months = months
        self.days = days
    }
}

/// Price-tiered durations in a single currency.
public struct PriceBands: Codable, Sendable, Equatable {
    /// ISO 4217 code the band boundaries are denominated in.
    public let currencyCode: String
    /// Ordered, non-overlapping. A price below the first band or between
    /// bands means the rule does not apply (e.g. no jótállás under 10 000 Ft).
    public let bands: [PriceBand]

    public init(currencyCode: String, bands: [PriceBand]) {
        self.currencyCode = currencyCode
        self.bands = bands
    }

    /// The band containing `price`, or nil when the price falls outside all
    /// bands.
    public func band(containing price: Decimal) -> PriceBand? {
        bands.first { $0.contains(price) }
    }
}

/// One price tier. Bounds are decimal strings in JSON to keep money exact;
/// inclusivity is explicit because statutes mix "elérő" (inclusive) with
/// "felett" (exclusive).
public struct PriceBand: Codable, Sendable, Equatable {
    public let min: String?
    /// Defaults to true (bound included) when omitted.
    public let minIncluded: Bool?
    public let max: String?
    /// Defaults to true (bound included) when omitted.
    public let maxIncluded: Bool?
    public let duration: RuleDuration

    public init(
        min: String? = nil,
        minIncluded: Bool? = nil,
        max: String? = nil,
        maxIncluded: Bool? = nil,
        duration: RuleDuration
    ) {
        self.min = min
        self.minIncluded = minIncluded
        self.max = max
        self.maxIncluded = maxIncluded
        self.duration = duration
    }

    public var minValue: Decimal? {
        min.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    public var maxValue: Decimal? {
        max.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    public func contains(_ price: Decimal) -> Bool {
        if let lower = minValue {
            if minIncluded ?? true {
                guard price >= lower else { return false }
            } else {
                guard price > lower else { return false }
            }
        }
        if let upper = maxValue {
            if maxIncluded ?? true {
                guard price <= upper else { return false }
            } else {
                guard price < upper else { return false }
            }
        }
        return true
    }
}

/// A link to the official legal text a rule is derived from.
public struct RuleSource: Codable, Sendable, Equatable {
    public let title: String
    public let url: String

    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}
