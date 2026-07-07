import Foundation
import Testing
@testable import WarrantyRules

@Suite("Bundled rule sets")
struct BundledRuleSetTests {

    @Test("all bundled rule sets load and pass full validation")
    func bundledLoads() throws {
        let store = try RuleStore.bundled()
        #expect(Set(store.ruleSets.keys) == ["EU", "HU", "DE", "AT"])
    }

    @Test("every bundled rule cites at least one https official source")
    func sourcesPresent() throws {
        let store = try RuleStore.bundled()
        for set in store.ruleSets.values {
            for rule in set.rules {
                #expect(!rule.sources.isEmpty, "rule \(rule.id) has no sources")
                for source in rule.sources {
                    #expect(
                        source.url.hasPrefix("https://"),
                        "rule \(rule.id) source is not https: \(source.url)"
                    )
                }
            }
        }
    }

    @Test("every bundled set carries a version and a verification date")
    func versionAndVerificationStamps() throws {
        let store = try RuleStore.bundled()
        for set in store.ruleSets.values {
            #expect(!set.ruleSetVersion.isEmpty)
            // contentVerified format is enforced by validation; assert the
            // stamp is not older than the rule set version's year to catch
            // stale copies at review time.
            #expect(set.contentVerified >= "2026-01-01")
        }
    }

    @Test("known country resolves to its own set, unknown falls back to EU")
    func fallbackResolution() throws {
        let store = try RuleStore.bundled()
        let hungary = store.ruleSet(forCountry: "HU")
        #expect(hungary.ruleSet.ruleSetID == "HU")
        #expect(!hungary.isFallback)

        let lowercase = store.ruleSet(forCountry: "de")
        #expect(lowercase.ruleSet.ruleSetID == "DE")
        #expect(!lowercase.isFallback)

        let france = store.ruleSet(forCountry: "FR")
        #expect(france.ruleSet.ruleSetID == "EU")
        #expect(france.isFallback)
    }

    @Test("every EU country's baseline: legal guarantee on both channels, withdrawal online-only")
    func baselineShape() throws {
        let store = try RuleStore.bundled()
        for set in store.ruleSets.values {
            let guarantees = set.rules.filter { $0.kind == .legalGuarantee }
            #expect(guarantees.count == 1, "\(set.ruleSetID) must have exactly one legal guarantee")
            #expect(guarantees.first?.channels.count == 2)

            let withdrawals = set.rules.filter { $0.kind == .withdrawal }
            #expect(withdrawals.count == 1, "\(set.ruleSetID) must have exactly one withdrawal rule")
            #expect(withdrawals.first?.channels == [.online])
            #expect(withdrawals.first?.duration == .days(14))
            #expect(withdrawals.first?.clockStart == .delivery)
        }
    }
}

@Suite("Rule set validation")
struct RuleSetValidationTests {

    private func makeStore(_ rules: [Rule]) throws -> RuleStore {
        try RuleStore(ruleSets: [testRuleSet(rules: rules)])
    }

    @Test("missing EU fallback set is rejected")
    func missingFallback() {
        let set = RuleSet(
            schemaVersion: 1,
            ruleSetID: "HU",
            ruleSetVersion: "test-1",
            contentVerified: "2026-07-07",
            rules: [testRule(duration: .months(24))]
        )
        #expect(throws: RuleStoreError.missingFallbackRuleSet(expected: "EU")) {
            try RuleStore(ruleSets: [set])
        }
    }

    @Test("unsupported schema version is rejected")
    func unsupportedSchema() {
        let set = RuleSet(
            schemaVersion: 2,
            ruleSetID: "EU",
            ruleSetVersion: "test-1",
            contentVerified: "2026-07-07",
            rules: [testRule(duration: .months(24))]
        )
        #expect(
            throws: RuleStoreError.unsupportedSchemaVersion(ruleSetID: "EU", found: 2, supported: 1)
        ) {
            try RuleStore(ruleSets: [set])
        }
    }

    @Test("duplicate rule IDs within a set are rejected")
    func duplicateRuleIDs() {
        let rules = [
            testRule(id: "dup", duration: .months(24)),
            testRule(id: "dup", kind: .withdrawal, duration: .days(14)),
        ]
        #expect(throws: RuleStoreError.duplicateRuleID(ruleSetID: "EU", ruleID: "dup")) {
            try makeStore(rules)
        }
    }

    @Test("a rule with both duration and price bands is rejected")
    func bothDurationSources() {
        let bands = PriceBands(
            currencyCode: "HUF",
            bands: [PriceBand(min: "10000", duration: .months(24))]
        )
        let rule = testRule(duration: .months(24), priceBands: bands)
        #expect(throws: RuleStoreError.durationAndPriceBandsBothSet(ruleID: "test.rule")) {
            try makeStore([rule])
        }
    }

    @Test("a rule with neither duration nor price bands is rejected")
    func noDurationSource() {
        #expect(throws: RuleStoreError.durationAndPriceBandsBothMissing(ruleID: "test.rule")) {
            try makeStore([testRule()])
        }
    }

    @Test("zero, negative, two-unit, and unit-less durations are rejected")
    func invalidDurations() {
        let broken: [RuleDuration] = [
            RuleDuration(months: 0, days: nil),
            RuleDuration(months: -24, days: nil),
            RuleDuration(months: nil, days: 0),
            RuleDuration(months: 24, days: 14),
            RuleDuration(months: nil, days: nil),
        ]
        for duration in broken {
            #expect(throws: RuleStoreError.invalidDuration(ruleID: "test.rule")) {
                try makeStore([testRule(duration: duration)])
            }
        }
    }

    @Test("a rule without sources is rejected")
    func noSources() {
        let rule = Rule(
            id: "test.rule",
            kind: .legalGuarantee,
            channels: [.online],
            clockStart: .purchase,
            duration: .months(24),
            explanationKey: "rule.test",
            sources: []
        )
        #expect(throws: RuleStoreError.noSources(ruleID: "test.rule")) {
            try makeStore([rule])
        }
    }

    @Test("non-http(s) source URLs are rejected")
    func badSourceURL() {
        let rule = Rule(
            id: "test.rule",
            kind: .legalGuarantee,
            channels: [.online],
            clockStart: .purchase,
            duration: .months(24),
            explanationKey: "rule.test",
            sources: [RuleSource(title: "Bad", url: "file:///etc/passwd")]
        )
        #expect(
            throws: RuleStoreError.invalidSourceURL(ruleID: "test.rule", url: "file:///etc/passwd")
        ) {
            try makeStore([rule])
        }
    }

    @Test("malformed contentVerified dates are rejected")
    func badVerificationDate() {
        for bad in ["07-07-2026", "2026-13-01", "2026-02-30", "yesterday", ""] {
            let set = RuleSet(
                schemaVersion: 1,
                ruleSetID: "EU",
                ruleSetVersion: "test-1",
                contentVerified: bad,
                rules: [testRule(duration: .months(24))]
            )
            #expect(
                throws: RuleStoreError.invalidContentVerifiedDate(ruleSetID: "EU", value: bad)
            ) {
                try RuleStore(ruleSets: [set])
            }
        }
    }

    @Test("overlapping price bands are rejected")
    func overlappingBands() {
        // Both bands include 250000 → a price could match two durations.
        let bands = PriceBands(
            currencyCode: "HUF",
            bands: [
                PriceBand(min: "10000", max: "250000", duration: .months(24)),
                PriceBand(min: "250000", minIncluded: true, duration: .months(36)),
            ]
        )
        #expect(throws: RuleStoreError.self) {
            try makeStore([testRule(priceBands: bands)])
        }
    }

    @Test("adjacent bands with complementary inclusivity are accepted")
    func adjacentBandsOK() throws {
        // ≤ 250000 then > 250000 — exactly the jótállás shape.
        let bands = PriceBands(
            currencyCode: "HUF",
            bands: [
                PriceBand(min: "10000", max: "250000", duration: .months(24)),
                PriceBand(min: "250000", minIncluded: false, duration: .months(36)),
            ]
        )
        _ = try makeStore([testRule(priceBands: bands)])
    }

    @Test("an unbounded band anywhere but last is rejected")
    func unboundedMiddleBand() {
        let bands = PriceBands(
            currencyCode: "HUF",
            bands: [
                PriceBand(min: "10000", duration: .months(24)),
                PriceBand(min: "250000", minIncluded: false, duration: .months(36)),
            ]
        )
        #expect(throws: RuleStoreError.self) {
            try makeStore([testRule(priceBands: bands)])
        }
    }

    @Test("non-decimal band bounds and bad currency codes are rejected")
    func malformedBands() {
        let badBound = PriceBands(
            currencyCode: "HUF",
            bands: [PriceBand(min: "ten thousand", duration: .months(24))]
        )
        #expect(throws: RuleStoreError.self) {
            try makeStore([testRule(priceBands: badBound)])
        }

        let badCurrency = PriceBands(
            currencyCode: "huf",
            bands: [PriceBand(min: "10000", duration: .months(24))]
        )
        #expect(throws: RuleStoreError.self) {
            try makeStore([testRule(priceBands: badCurrency)])
        }
    }
}
