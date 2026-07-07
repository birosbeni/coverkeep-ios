import Foundation
import SwiftData

/// A claim/repair/return log entry on an item. Attachments (e.g. a repair
/// quote photo) arrive with Slice 4 via KeepCore.
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

    var item: Item?

    var kind: EventKind {
        get { EventKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    init(date: Date = .now, kind: EventKind, note: String = "") {
        self.date = date
        self.kindRawValue = kind.rawValue
        self.note = note
        self.createdAt = .now
    }
}
