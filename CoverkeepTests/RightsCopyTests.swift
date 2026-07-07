import Foundation
import Testing
import WarrantyRules
@testable import Coverkeep

@Suite("Rights copy")
struct RightsCopyTests {

    @Test("every explanation key in the bundled rule sets has plain-language copy")
    func allBundledKeysCovered() throws {
        let store = try RuleStore.bundled()
        for set in store.ruleSets.values {
            for rule in set.rules {
                #expect(
                    RightsCopy.explanation(forKey: rule.explanationKey) != nil,
                    "missing copy for \(rule.explanationKey) — a rule shipped without its explanation"
                )
            }
        }
    }

    @Test("an unknown key degrades to nil instead of wrong copy")
    func unknownKey() {
        #expect(RightsCopy.explanation(forKey: "rule.fr.futureRule") == nil)
    }

    @Test("the disclaimer says it is not legal advice")
    func disclaimerPresent() {
        #expect(RightsCopy.disclaimer.localizedCaseInsensitiveContains("not legal advice"))
    }

    @Test("every coverage kind has a title and every skip reason a message")
    func kindsAndSkips() {
        for kind in CoverageKind.allCases {
            #expect(!RightsCopy.title(for: kind).isEmpty)
        }
        let reasons: [SkippedRule.Reason] = [
            .priceUnknown,
            .currencyMismatch(expected: "HUF", actual: "EUR"),
            .priceOutsideBands,
        ]
        for reason in reasons {
            let skipped = SkippedRule(
                ruleID: "x", kind: .commercialWarranty, reason: reason, explanationKey: "x"
            )
            #expect(!RightsCopy.message(for: skipped).isEmpty)
        }
    }
}
