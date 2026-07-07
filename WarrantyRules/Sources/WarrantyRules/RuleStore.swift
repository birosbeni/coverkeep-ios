import Foundation

/// Validation and loading failures. Every case carries enough context to
/// pinpoint the offending rule set or rule — no silent catches anywhere.
public enum RuleStoreError: Error, Equatable, CustomStringConvertible {
    case noBundledRuleSets
    case unsupportedSchemaVersion(ruleSetID: String, found: Int, supported: Int)
    case duplicateRuleSetID(String)
    case missingFallbackRuleSet(expected: String)
    case emptyRuleSet(ruleSetID: String)
    case invalidContentVerifiedDate(ruleSetID: String, value: String)
    case duplicateRuleID(ruleSetID: String, ruleID: String)
    case noChannels(ruleID: String)
    case durationAndPriceBandsBothSet(ruleID: String)
    case durationAndPriceBandsBothMissing(ruleID: String)
    case invalidDuration(ruleID: String)
    case noSources(ruleID: String)
    case invalidSourceURL(ruleID: String, url: String)
    case invalidPriceBands(ruleID: String, reason: String)

    public var description: String {
        switch self {
        case .noBundledRuleSets:
            return "No rule set JSON files found in the bundled Rules directory."
        case let .unsupportedSchemaVersion(id, found, supported):
            return "Rule set \(id) has schemaVersion \(found); this build supports \(supported)."
        case let .duplicateRuleSetID(id):
            return "More than one rule set claims the ID \(id)."
        case let .missingFallbackRuleSet(expected):
            return "The fallback rule set \(expected) is missing."
        case let .emptyRuleSet(id):
            return "Rule set \(id) contains no rules."
        case let .invalidContentVerifiedDate(id, value):
            return "Rule set \(id) has contentVerified \"\(value)\"; expected yyyy-MM-dd."
        case let .duplicateRuleID(setID, ruleID):
            return "Rule set \(setID) declares rule \(ruleID) more than once."
        case let .noChannels(ruleID):
            return "Rule \(ruleID) applies to no channels."
        case let .durationAndPriceBandsBothSet(ruleID):
            return "Rule \(ruleID) sets both duration and priceBands; exactly one is required."
        case let .durationAndPriceBandsBothMissing(ruleID):
            return "Rule \(ruleID) sets neither duration nor priceBands; exactly one is required."
        case let .invalidDuration(ruleID):
            return "Rule \(ruleID) has a duration that is not exactly one positive unit."
        case let .noSources(ruleID):
            return "Rule \(ruleID) cites no official sources."
        case let .invalidSourceURL(ruleID, url):
            return "Rule \(ruleID) cites a non-http(s) source URL: \(url)"
        case let .invalidPriceBands(ruleID, reason):
            return "Rule \(ruleID) has invalid price bands: \(reason)"
        }
    }
}

/// Holds all loaded rule sets, fully validated at construction. Unknown
/// countries resolve to the EU fallback set, flagged so the UI can say
/// "showing EU minimum rules".
public struct RuleStore: Sendable {
    public static let supportedSchemaVersion = 1
    public static let fallbackRuleSetID = "EU"

    public let ruleSets: [String: RuleSet]

    /// Loads and validates every JSON file bundled under Rules/.
    public static func bundled() throws -> RuleStore {
        guard
            let urls = Bundle.module.urls(
                forResourcesWithExtension: "json", subdirectory: "Rules"
            ),
            !urls.isEmpty
        else {
            throw RuleStoreError.noBundledRuleSets
        }
        let decoder = JSONDecoder()
        let sets = try urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try decoder.decode(RuleSet.self, from: Data(contentsOf: $0)) }
        return try RuleStore(ruleSets: sets)
    }

    /// Validates and indexes the given rule sets. The fallback set
    /// (`fallbackRuleSetID`) must be present.
    public init(ruleSets sets: [RuleSet]) throws {
        var indexed: [String: RuleSet] = [:]
        for set in sets {
            guard set.schemaVersion == Self.supportedSchemaVersion else {
                throw RuleStoreError.unsupportedSchemaVersion(
                    ruleSetID: set.ruleSetID,
                    found: set.schemaVersion,
                    supported: Self.supportedSchemaVersion
                )
            }
            guard indexed[set.ruleSetID] == nil else {
                throw RuleStoreError.duplicateRuleSetID(set.ruleSetID)
            }
            try Self.validate(set)
            indexed[set.ruleSetID] = set
        }
        guard indexed[Self.fallbackRuleSetID] != nil else {
            throw RuleStoreError.missingFallbackRuleSet(expected: Self.fallbackRuleSetID)
        }
        self.ruleSets = indexed
    }

    /// The rule set for a country, or the EU fallback (flagged) when the
    /// country has no vetted set of its own.
    public func ruleSet(forCountry countryCode: String) -> (ruleSet: RuleSet, isFallback: Bool) {
        let code = countryCode.uppercased()
        if let set = ruleSets[code] {
            return (set, false)
        }
        // Presence of the fallback set is guaranteed by init validation.
        guard let fallback = ruleSets[Self.fallbackRuleSetID] else {
            preconditionFailure("RuleStore validated without a fallback rule set")
        }
        return (fallback, true)
    }

    private static func validate(_ set: RuleSet) throws {
        guard !set.rules.isEmpty else {
            throw RuleStoreError.emptyRuleSet(ruleSetID: set.ruleSetID)
        }
        guard Self.isISODate(set.contentVerified) else {
            throw RuleStoreError.invalidContentVerifiedDate(
                ruleSetID: set.ruleSetID, value: set.contentVerified
            )
        }
        var seenRuleIDs: Set<String> = []
        for rule in set.rules {
            guard seenRuleIDs.insert(rule.id).inserted else {
                throw RuleStoreError.duplicateRuleID(ruleSetID: set.ruleSetID, ruleID: rule.id)
            }
            guard !rule.channels.isEmpty else {
                throw RuleStoreError.noChannels(ruleID: rule.id)
            }
            switch (rule.duration, rule.priceBands) {
            case (.some, .some):
                throw RuleStoreError.durationAndPriceBandsBothSet(ruleID: rule.id)
            case (.none, .none):
                throw RuleStoreError.durationAndPriceBandsBothMissing(ruleID: rule.id)
            case let (.some(duration), .none):
                try validate(duration, ruleID: rule.id)
            case let (.none, .some(bands)):
                try validate(bands, ruleID: rule.id)
            }
            if let burden = rule.burdenOfProof {
                try validate(burden, ruleID: rule.id)
            }
            guard !rule.sources.isEmpty else {
                throw RuleStoreError.noSources(ruleID: rule.id)
            }
            for source in rule.sources {
                guard
                    let url = URL(string: source.url),
                    let scheme = url.scheme?.lowercased(),
                    scheme == "https" || scheme == "http"
                else {
                    throw RuleStoreError.invalidSourceURL(ruleID: rule.id, url: source.url)
                }
            }
        }
    }

    private static func validate(_ duration: RuleDuration, ruleID: String) throws {
        switch (duration.months, duration.days) {
        case let (.some(months), .none) where months > 0:
            return
        case let (.none, .some(days)) where days > 0:
            return
        default:
            throw RuleStoreError.invalidDuration(ruleID: ruleID)
        }
    }

    private static func validate(_ priceBands: PriceBands, ruleID: String) throws {
        func fail(_ reason: String) -> RuleStoreError {
            .invalidPriceBands(ruleID: ruleID, reason: reason)
        }
        let code = priceBands.currencyCode
        guard code.count == 3, code == code.uppercased() else {
            throw fail("currencyCode \"\(code)\" is not an uppercase ISO 4217 code")
        }
        guard !priceBands.bands.isEmpty else {
            throw fail("no bands")
        }
        for band in priceBands.bands {
            try validate(band.duration, ruleID: ruleID)
            if band.min != nil, band.minValue == nil {
                throw fail("min \"\(band.min ?? "")\" is not a decimal")
            }
            if band.max != nil, band.maxValue == nil {
                throw fail("max \"\(band.max ?? "")\" is not a decimal")
            }
            if let lower = band.minValue, let upper = band.maxValue, lower > upper {
                throw fail("band lower bound \(lower) exceeds upper bound \(upper)")
            }
        }
        // Bands must be ordered and non-overlapping so that a price matches
        // at most one band. Every band except the last needs an upper bound;
        // every band except the first needs a lower bound.
        for (index, band) in priceBands.bands.enumerated() {
            if index < priceBands.bands.count - 1, band.max == nil {
                throw fail("band \(index) has no upper bound but is not the last band")
            }
            if index > 0, band.min == nil {
                throw fail("band \(index) has no lower bound but is not the first band")
            }
        }
        for (previous, next) in zip(priceBands.bands, priceBands.bands.dropFirst()) {
            guard let upper = previous.maxValue, let lower = next.minValue else {
                continue // already rejected above
            }
            let upperIncluded = previous.maxIncluded ?? true
            let lowerIncluded = next.minIncluded ?? true
            let ordered = upper < lower || (upper == lower && !(upperIncluded && lowerIncluded))
            guard ordered else {
                throw fail("bands overlap around \(upper)")
            }
        }
    }

    private static func isISODate(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard
            parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components).map {
            calendar.dateComponents([.year, .month, .day], from: $0)
                == DateComponents(year: year, month: month, day: day)
        } ?? false
    }
}
