import Foundation
import SwiftData
import WarrantyRules

/// One protection on an item — a withdrawal window, the legal guarantee, a
/// manufacturer warranty. Several coexist per item as the norm.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// no unique constraints; the `item` relationship is optional and its
/// inverse is declared on `Item.coverages`.
@Model
final class Coverage {
    /// Raw `CoverageKind` (WarrantyRules).
    var kindRawValue: String = CoverageKind.legalGuarantee.rawValue
    var startDate: Date = Date.now
    /// The LAST day the right can still be exercised (inclusive) — computed
    /// by the WarrantyRules engine or entered by hand, never derived with
    /// inline date math.
    var endDate: Date = Date.now
    /// Until when a defect is presumed to have existed at delivery
    /// (reversed burden of proof), when the underlying rule defines one.
    var burdenOfProofEndDate: Date?
    /// Raw `CoverageSource`: computed coverages show their rule source,
    /// manual ones are the user's own entry.
    var sourceRawValue: String = CoverageSource.manual.rawValue
    /// Provenance stamps for computed coverages, so a stored coverage never
    /// silently changes when a bundled rule file is updated. Nil for manual
    /// entries.
    var ruleID: String?
    var ruleSetID: String?
    var ruleSetVersion: String?
    /// String Catalog key of the plain-language explanation (computed
    /// coverages only).
    var explanationKey: String?
    /// True when the rule's clock starts at delivery but only the purchase
    /// date was known — the UI invites the user to correct it.
    var clockStartAssumed: Bool = false
    /// Days before `endDate` the reminder fires. Defaults per CLAUDE.md:
    /// 30 for long coverages, 3 for withdrawal windows.
    var reminderLeadDays: Int = 30
    var createdAt: Date = Date.now

    var item: Item?

    var kind: CoverageKind {
        get { CoverageKind(rawValue: kindRawValue) ?? .legalGuarantee }
        set { kindRawValue = newValue.rawValue }
    }

    var source: CoverageSource {
        get { CoverageSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    /// The default reminder lead for a coverage kind: withdrawal windows are
    /// days long, everything else gets the standard month of notice.
    static func defaultReminderLeadDays(for kind: CoverageKind) -> Int {
        kind == .withdrawal ? 3 : 30
    }

    /// A manual coverage.
    init(
        kind: CoverageKind,
        startDate: Date,
        endDate: Date,
        reminderLeadDays: Int? = nil
    ) {
        self.kindRawValue = kind.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.sourceRawValue = CoverageSource.manual.rawValue
        self.reminderLeadDays = reminderLeadDays ?? Self.defaultReminderLeadDays(for: kind)
        self.createdAt = .now
    }

    /// A coverage computed by the WarrantyRules engine, carrying its full
    /// provenance.
    init(computed: ComputedCoverage) {
        self.kindRawValue = computed.kind.rawValue
        self.startDate = computed.startDate
        self.endDate = computed.endDate
        self.burdenOfProofEndDate = computed.burdenOfProofEndDate
        self.sourceRawValue = CoverageSource.computedFromRules.rawValue
        self.ruleID = computed.ruleID
        self.ruleSetID = computed.ruleSetID
        self.ruleSetVersion = computed.ruleSetVersion
        self.explanationKey = computed.explanationKey
        self.clockStartAssumed = computed.clockStartAssumed
        self.reminderLeadDays = Self.defaultReminderLeadDays(for: computed.kind)
        self.createdAt = .now
    }
}
