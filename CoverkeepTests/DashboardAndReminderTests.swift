import Foundation
import SwiftData
import Testing
import WarrantyRules
@testable import Coverkeep

@Suite("Dashboard selection and reminder planning")
@MainActor
struct DashboardAndReminderTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A vault with one item carrying: an active withdrawal (ends +10d), a
    /// far-away guarantee (+700d), a guarantee inside its lead window
    /// (+20d, lead 30), and an expired warranty (−5d); plus an archived
    /// item with an imminent deadline that must never surface.
    private func makeVault(now: Date) throws -> (ModelContext, [Item]) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        func coverage(_ kind: CoverageKind, endsIn days: Int, lead: Int) -> Coverage {
            Coverage(
                kind: kind,
                startDate: calendar.date(byAdding: .day, value: -30, to: now)!,
                endDate: calendar.date(byAdding: .day, value: days, to: now)!,
                reminderLeadDays: lead
            )
        }

        let laptop = Item(name: "Laptop")
        context.insert(laptop)
        for c in [
            coverage(.withdrawal, endsIn: 10, lead: 3),
            coverage(.legalGuarantee, endsIn: 700, lead: 30),
            coverage(.commercialWarranty, endsIn: 20, lead: 30),
            coverage(.extendedWarranty, endsIn: -5, lead: 30),
        ] {
            c.item = laptop
            context.insert(c)
        }

        let archived = Item(name: "Old phone")
        archived.archived = true
        context.insert(archived)
        let archivedCoverage = coverage(.legalGuarantee, endsIn: 5, lead: 30)
        archivedCoverage.item = archived
        context.insert(archivedCoverage)

        try context.save()
        return (context, [laptop, archived])
    }

    // MARK: Dashboard

    @Test("return windows show all active withdrawals, even outside the lead window")
    func returnWindows() throws {
        let now = date(2026, 7, 8)
        let (_, items) = try makeVault(now: now)
        let windows = Dashboard.returnWindows(in: items, now: now, calendar: calendar)
        #expect(windows.count == 1)
        #expect(windows.first?.coverage.kind == .withdrawal)
    }

    @Test("expiring soon shows only coverages inside their lead window, soonest first")
    func expiringSoon() throws {
        let now = date(2026, 7, 8)
        let (_, items) = try makeVault(now: now)
        let expiring = Dashboard.expiringSoon(in: items, now: now, calendar: calendar)
        // Not the +700d guarantee, not the expired warranty, not the
        // withdrawal (it lives in its own section), nothing archived.
        #expect(expiring.map(\.coverage.kind) == [.commercialWarranty])
    }

    // MARK: Reminder planning

    @Test("every live coverage of every unarchived item gets exactly one reminder")
    func planContents() throws {
        let now = date(2026, 7, 8)
        let (_, items) = try makeVault(now: now)
        let plan = ReminderPlanner.plan(for: items, now: now, calendar: calendar)

        // withdrawal +10d, warranty +20d, guarantee +700d — expired and
        // archived excluded; sorted by end date.
        #expect(plan.count == 3)
        #expect(plan.map(\.leadDays) == [3, 30, 30])
        #expect(plan[0].endDate < plan[1].endDate)
        #expect(plan[1].endDate < plan[2].endDate)
    }

    @Test("reminder identity is the coverage's stable reminderID")
    func planIdentity() throws {
        let now = date(2026, 7, 8)
        let (_, items) = try makeVault(now: now)
        let coverageIDs = Set(
            (items[0].coverages ?? []).map(\.reminderID)
        )
        let plan = ReminderPlanner.plan(for: items, now: now, calendar: calendar)
        #expect(plan.allSatisfy { coverageIDs.contains($0.id) })
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test("the notification body names the right, the item, and the date")
    func planBody() throws {
        let now = date(2026, 7, 8)
        let (_, items) = try makeVault(now: now)
        let plan = ReminderPlanner.plan(for: items, now: now, calendar: calendar)
        let withdrawalBody = try #require(plan.first?.body)
        #expect(withdrawalBody.contains("Laptop"))
        #expect(withdrawalBody.contains(RightsCopy.title(for: .withdrawal)))
    }

    @Test("a coverage ending today is still planned; yesterday's is not")
    func endTodayBoundary() throws {
        let now = date(2026, 7, 8)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, ReceiptPage.self, Coverage.self, Event.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        context.insert(item)
        let today = Coverage(kind: .withdrawal, startDate: now, endDate: now, reminderLeadDays: 3)
        today.item = item
        let yesterday = Coverage(
            kind: .withdrawal,
            startDate: now,
            endDate: calendar.date(byAdding: .day, value: -1, to: now)!,
            reminderLeadDays: 3
        )
        yesterday.item = item
        context.insert(today)
        context.insert(yesterday)

        let plan = ReminderPlanner.plan(for: [item], now: now, calendar: calendar)
        #expect(plan.map(\.id) == [today.reminderID])
    }
}
