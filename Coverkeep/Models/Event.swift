import Foundation
import SwiftData
import KeepCore

/// A claim/repair/return log entry on an item, optionally carrying one
/// attachment (a repair quote, a claim confirmation) captured through
/// KeepCore's pipeline and stored byte-for-byte like receipt pages.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// no unique constraints; the `item` relationship is optional and its
/// inverse is declared on `Item.events`.
@Model
final class Event {
    var date: Date = Date.now
    /// Raw `EventKind`.
    var kindRawValue: String = EventKind.claim.rawValue
    var note: String = ""
    var createdAt: Date = Date.now

    /// The optional single attachment (spec: date, kind, note, attachment).
    var attachmentFileName: String?
    /// Raw `KeepCore.AttachmentKind` when an attachment exists.
    var attachmentKindRawValue: String?
    @Attribute(.externalStorage) var attachmentData: Data?

    var item: Item?

    var kind: EventKind {
        get { EventKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    var attachmentKind: AttachmentKind? {
        attachmentKindRawValue.flatMap(AttachmentKind.init(rawValue:))
    }

    /// The attachment as a draft for editing, when one exists.
    var attachmentDraft: AttachmentDraft? {
        guard let data = attachmentData, let kind = attachmentKind else { return nil }
        return AttachmentDraft(
            fileName: attachmentFileName ?? "attachment",
            kind: kind,
            data: data
        )
    }

    func setAttachment(_ draft: AttachmentDraft?) {
        attachmentFileName = draft?.fileName
        attachmentKindRawValue = draft?.kind.rawValue
        attachmentData = draft?.data
    }

    init(date: Date = .now, kind: EventKind, note: String = "") {
        self.date = date
        self.kindRawValue = kind.rawValue
        self.note = note
        self.createdAt = .now
    }
}

extension EventKind {
    var label: String {
        switch self {
        case .claim: String(localized: "Claim")
        case .repair: String(localized: "Repair")
        case .returned: String(localized: "Return")
        case .other: String(localized: "Note")
        }
    }

    var systemImage: String {
        switch self {
        case .claim: "exclamationmark.bubble"
        case .repair: "wrench.and.screwdriver"
        case .returned: "arrow.uturn.backward.circle"
        case .other: "text.bubble"
        }
    }
}
