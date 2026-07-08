import SwiftUI
import SwiftData
// KeepCore is linked from Slice 0 so the shared infrastructure (reminders,
// attachments, export, paywall) is wired before the slices that use it.
import KeepCore
import WarrantyRules

@main
struct CoverkeepApp: App {
    @State private var reminderSync = ReminderSync()

    var body: some Scene {
        WindowGroup {
            ItemListView()
                .environment(reminderSync)
        }
        // Local store for now; CloudKit private-database sync is Slice 5.
        // The models are CloudKit-compatible from day one (see Models/).
        .modelContainer(
            for: [Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self]
        )
    }
}
