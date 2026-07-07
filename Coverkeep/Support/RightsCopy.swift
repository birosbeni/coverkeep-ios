import Foundation
import WarrantyRules

/// All user-facing copy for the rights engine: plain-language explanations
/// keyed by the rule files' `explanationKey`, coverage-kind names, skip
/// reasons, and the mandatory disclaimer. The "you have these rights until
/// these dates" moment lives or dies on this copy — plain language over
/// legal jargon, but every documented simplification stated honestly.
enum RightsCopy {

    /// The plain-language explanation for a rule, or nil for a key this
    /// build doesn't know (a test guards that all bundled keys are covered).
    static func explanation(forKey key: String) -> String? {
        switch key {
        case "rule.eu.legalGuarantee":
            return String(
                localized: "rule.eu.legalGuarantee",
                defaultValue: """
                EU-wide minimum: the seller is responsible for 2 years from \
                delivery for any defect that already existed when you \
                received the goods. In the first year the defect is presumed \
                to have been there from the start — the seller has to prove \
                otherwise. Your country's law may give you more than this.
                """
            )
        case "rule.eu.withdrawal":
            return String(
                localized: "rule.eu.withdrawal",
                defaultValue: """
                You can return an online purchase within 14 days of the day \
                you receive it, for any reason. Counted in calendar days \
                here; if the last day falls on a holiday, the law can give \
                you until the next working day. Some goods are exempt \
                (personalised items, unsealed hygiene goods, and more).
                """
            )
        case "rule.hu.legalGuarantee":
            return String(
                localized: "rule.hu.legalGuarantee",
                defaultValue: """
                Kellékszavatosság: the seller is responsible for 2 years \
                from delivery for any defect that already existed at \
                delivery. In the first year the defect is presumed to have \
                been there from the start — the seller has to prove \
                otherwise.
                """
            )
        case "rule.hu.mandatoryWarranty":
            return String(
                localized: "rule.hu.mandatoryWarranty",
                defaultValue: """
                Jótállás: new durable goods costing at least 10 000 Ft \
                carry a mandatory warranty — 2 years up to 250 000 Ft, \
                3 years above that. It applies to the product types listed \
                in the decree's annex (most electronics and appliances), so \
                check that your item qualifies. Unlike the legal guarantee, \
                during the jótállás it is the seller's burden to prove the \
                product was faultless.
                """
            )
        case "rule.hu.withdrawal":
            return String(
                localized: "rule.hu.withdrawal",
                defaultValue: """
                Elállási jog: you can return an online purchase within 14 \
                days of receiving it, without giving any reason. Counted in \
                calendar days. Some goods are exempt (personalised items, \
                unsealed hygiene goods, and more).
                """
            )
        case "rule.de.legalGuarantee":
            return String(
                localized: "rule.de.legalGuarantee",
                defaultValue: """
                Gewährleistung (Mängelhaftung): the seller is responsible \
                for 2 years from delivery for any defect that already \
                existed at delivery. In the first year the defect is \
                presumed to have been there from the start — the seller has \
                to prove otherwise.
                """
            )
        case "rule.de.withdrawal":
            return String(
                localized: "rule.de.withdrawal",
                defaultValue: """
                Widerrufsrecht: you can return an online purchase within 14 \
                days of receiving it, without giving any reason. Counted in \
                calendar days. Some goods are exempt (personalised items, \
                unsealed hygiene goods, and more).
                """
            )
        case "rule.at.legalGuarantee":
            return String(
                localized: "rule.at.legalGuarantee",
                defaultValue: """
                Gewährleistung: the seller is responsible for 2 years from \
                handover for any defect that already existed at handover. \
                In the first year the defect is presumed to have been there \
                from the start — the seller has to prove otherwise. Claims \
                stay enforceable for a further 3 months after the 2 years \
                end.
                """
            )
        case "rule.at.withdrawal":
            return String(
                localized: "rule.at.withdrawal",
                defaultValue: """
                Rücktrittsrecht: you can return an online purchase within \
                14 days of receiving it, without giving any reason. Counted \
                in calendar days. Some goods are exempt (personalised \
                items, unsealed hygiene goods, and more).
                """
            )
        default:
            return nil
        }
    }

    static func title(for kind: CoverageKind) -> String {
        switch kind {
        case .legalGuarantee:
            String(localized: "Legal guarantee")
        case .commercialWarranty:
            String(localized: "Warranty")
        case .extendedWarranty:
            String(localized: "Extended warranty")
        case .withdrawal:
            String(localized: "Return window")
        }
    }

    static func message(for skipped: SkippedRule) -> String {
        switch skipped.reason {
        case .priceUnknown:
            String(localized: "Enter the price to see whether a mandatory warranty applies.")
        case let .currencyMismatch(expected, _):
            String(localized: "Mandatory-warranty tiers are defined in \(expected); enter the price in \(expected) to match them.")
        case .priceOutsideBands:
            String(localized: "No mandatory warranty at this price — it only applies above a minimum price.")
        }
    }

    /// Shown when a delivery-clock coverage had to fall back to the
    /// purchase date.
    static var assumedClockNote: String {
        String(localized: "Counted from the purchase date — set the delivery date if it arrived later.")
    }

    /// Shown when the country had no vetted rule set.
    static var fallbackRuleSetNote: String {
        String(localized: "No vetted rule set for this country yet — showing the EU minimum rules.")
    }

    /// The mandatory legal disclaimer, shown wherever rights are stated.
    static var disclaimer: String {
        String(localized: "General information based on official sources — not legal advice.")
    }

    /// One line under a coverage: "Until 21 July 2026 · seller must disprove
    /// defects until 10 July 2027" is built by the views; this is the burden
    /// label they share.
    static func burdenOfProofNote(until date: Date) -> String {
        String(localized: "Defects are presumed present from the start until \(date.formatted(date: .long, time: .omitted)).")
    }
}
