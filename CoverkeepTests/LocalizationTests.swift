import Foundation
import Testing
import WarrantyRules
@testable import Coverkeep

@Suite("Hungarian localization")
struct LocalizationTests {

    private func hungarianBundle() throws -> Bundle {
        let path = try #require(
            Bundle.main.path(forResource: "hu", ofType: "lproj"),
            "hu.lproj missing from the app bundle — HU localization broke"
        )
        return try #require(Bundle(path: path))
    }

    @Test("every bundled rule explanation has Hungarian copy")
    func ruleExplanationsTranslated() throws {
        let bundle = try hungarianBundle()
        let store = try RuleStore.bundled()
        for set in store.ruleSets.values {
            for rule in set.rules {
                let translated = bundle.localizedString(
                    forKey: rule.explanationKey, value: rule.explanationKey, table: nil
                )
                // A missing entry falls back to the key itself.
                #expect(
                    translated != rule.explanationKey,
                    "no HU translation for \(rule.explanationKey)"
                )
            }
        }
    }

    @Test("the HU jótállás explanation states the vetted two-tier thresholds")
    func jotallasCopy() throws {
        let bundle = try hungarianBundle()
        let text = bundle.localizedString(
            forKey: "rule.hu.mandatoryWarranty", value: "", table: nil
        )
        #expect(text.contains("10 000"))
        #expect(text.contains("250 000"))
        #expect(text.contains("2 év"))
        #expect(text.contains("3 év"))
    }

    @Test("core UI terms are translated, not echoed keys")
    func coreTerms() throws {
        let bundle = try hungarianBundle()
        let samples = [
            ("Legal guarantee", "Kellékszavatosság"),
            ("Return window", "Elállási idő"),
            ("Your rights", "A jogaid"),
            ("Settings", "Beállítások"),
        ]
        for (key, expected) in samples {
            let translated = bundle.localizedString(forKey: key, value: key, table: nil)
            #expect(translated == expected, "\(key) → \(translated)")
        }
    }

    @Test("the not-legal-advice disclaimer exists in Hungarian")
    func disclaimer() throws {
        let bundle = try hungarianBundle()
        let text = bundle.localizedString(
            forKey: "General information based on official sources — not legal advice.",
            value: "",
            table: nil
        )
        #expect(text.contains("nem jogi tanácsadás"))
    }
}
