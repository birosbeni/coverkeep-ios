import Foundation
import WarrantyRules

/// One dashboard line: a deadline and the item it belongs to.
struct DeadlineEntry: Identifiable {
    let coverage: Coverage
    let item: Item

    var id: PersistentIdentifier { coverage.persistentModelID }
}

import SwiftData

/// Selects what the home dashboard surfaces: active withdrawal windows
/// (counting down in days from day one — they are short and irreversible),
/// and everything else once it enters its reminder lead window.
enum Dashboard {

    /// Active return/withdrawal windows on unarchived items, soonest first.
    static func returnWindows(
        in items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DeadlineEntry] {
        entries(in: items) { coverage in
            coverage.kind == .withdrawal
                && DeadlineStatus.of(
                    endDate: coverage.endDate,
                    leadDays: coverage.reminderLeadDays,
                    now: now,
                    calendar: calendar
                ) != .expired
        }
    }

    /// Non-withdrawal coverages inside their lead window, soonest first.
    static func expiringSoon(
        in items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DeadlineEntry] {
        entries(in: items) { coverage in
            guard coverage.kind != .withdrawal else { return false }
            if case .expiringSoon = DeadlineStatus.of(
                endDate: coverage.endDate,
                leadDays: coverage.reminderLeadDays,
                now: now,
                calendar: calendar
            ) {
                return true
            }
            return false
        }
    }

    private static func entries(
        in items: [Item],
        where matches: (Coverage) -> Bool
    ) -> [DeadlineEntry] {
        items
            .filter { !$0.archived }
            .flatMap { item in
                (item.coverages ?? [])
                    .filter(matches)
                    .map { DeadlineEntry(coverage: $0, item: item) }
            }
            .sorted { $0.coverage.endDate < $1.coverage.endDate }
    }
}
