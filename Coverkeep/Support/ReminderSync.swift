import Foundation
import SwiftData
import UserNotifications
import KeepCore

/// Keeps the pending local notifications in lockstep with the vault: after
/// any mutation that touches coverages (and on foreground), the full set is
/// wiped and rebuilt from `ReminderPlanner`'s output. Idempotent, so
/// calling it too often is harmless; deleted coverages disappear because
/// the wipe is total (Coverkeep schedules no other notifications).
///
/// Fully functional without permission: scheduling is a no-op when denied,
/// and authorization is only requested once there is something to remind
/// about — the moment the first coverage lands, which is when the prompt
/// makes sense to a user.
@MainActor
@Observable
final class ReminderSync {
    let scheduler: ReminderScheduler

    init() {
        scheduler = ReminderScheduler(
            reminderTitle: String(localized: "Coverkeep deadline")
        )
    }

    func resync(items: [Item], calendar: Calendar = .current) async {
        let reminders = ReminderPlanner.plan(for: items, calendar: calendar)

        if !reminders.isEmpty {
            // Safe to call repeatedly; the system only prompts the first time.
            await scheduler.requestAuthorization()
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for reminder in reminders {
            await scheduler.scheduleReminder(
                taskID: reminder.id,
                body: reminder.body,
                dueDate: reminder.endDate,
                leadDays: reminder.leadDays,
                isActive: true,
                calendar: calendar
            )
        }
    }

    /// Convenience for call sites that have a `ModelContext` at hand.
    func resyncAll(in context: ModelContext) async {
        do {
            let items = try context.fetch(FetchDescriptor<Item>())
            await resync(items: items)
        } catch {
            // A fetch failure here must not take the UI down; the store is
            // the source of truth and the next resync will heal the set.
            assertionFailure("Reminder resync fetch failed: \(error)")
        }
    }
}
