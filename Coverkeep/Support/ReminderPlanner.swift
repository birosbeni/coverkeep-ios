import Foundation
import WarrantyRules

/// A coverage deadline that deserves a local notification. Pure data so the
/// planning is exhaustively testable; actual scheduling is a thin pass
/// through KeepCore's `ReminderScheduler`.
struct PlannedReminder: Equatable {
    let id: UUID
    let body: String
    let endDate: Date
    let leadDays: Int
}

/// Decides which reminders should exist right now: one per coverage of
/// every unarchived item, skipping deadlines that already passed. Whether a
/// fire date (endDate − leadDays) is still reachable is the scheduler's
/// call — a coverage inside its lead window still gets an "ends today"-era
/// reminder if the fire instant hasn't passed.
enum ReminderPlanner {

    static func plan(
        for items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        let today = calendar.startOfDay(for: now)
        var reminders: [PlannedReminder] = []
        for item in items where !item.archived {
            for coverage in item.coverages ?? [] {
                let end = calendar.startOfDay(for: coverage.endDate)
                guard end >= today else { continue }
                reminders.append(
                    PlannedReminder(
                        id: coverage.reminderID,
                        body: body(for: coverage, of: item),
                        endDate: coverage.endDate,
                        leadDays: coverage.reminderLeadDays
                    )
                )
            }
        }
        return reminders.sorted { $0.endDate < $1.endDate }
    }

    static func body(for coverage: Coverage, of item: Item) -> String {
        let kind = RightsCopy.title(for: coverage.kind)
        let date = coverage.endDate.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "\(kind) for “\(item.name)” ends \(date).")
    }
}
