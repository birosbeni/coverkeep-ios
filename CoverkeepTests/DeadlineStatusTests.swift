import Foundation
import Testing
@testable import Coverkeep

@Suite("Deadline status")
struct DeadlineStatusTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("well before the lead window the coverage is active")
    func active() {
        let status = DeadlineStatus.of(
            endDate: date(2028, 7, 7), leadDays: 30, now: date(2026, 7, 7), calendar: calendar
        )
        #expect(status == .active(daysRemaining: 731))
    }

    @Test("inside the lead window it is expiring — chip and reminder agree")
    func expiringAtLeadBoundary() {
        let status = DeadlineStatus.of(
            endDate: date(2026, 8, 6), leadDays: 30, now: date(2026, 7, 7), calendar: calendar
        )
        #expect(status == .expiringSoon(daysRemaining: 30))

        let dayBefore = DeadlineStatus.of(
            endDate: date(2026, 8, 7), leadDays: 30, now: date(2026, 7, 7), calendar: calendar
        )
        #expect(dayBefore == .active(daysRemaining: 31))
    }

    @Test("the inclusive last day still counts — 'ends today', not expired")
    func endsToday() {
        let status = DeadlineStatus.of(
            endDate: date(2026, 7, 7), leadDays: 3, now: date(2026, 7, 7), calendar: calendar
        )
        #expect(status == .expiringSoon(daysRemaining: 0))
    }

    @Test("the day after the end date it is expired")
    func expired() {
        let status = DeadlineStatus.of(
            endDate: date(2026, 7, 7), leadDays: 3, now: date(2026, 7, 8), calendar: calendar
        )
        #expect(status == .expired)
    }

    @Test("a mid-day 'now' does not shift the civil day count")
    func midDayNow() {
        let noon = date(2026, 7, 7).addingTimeInterval(12 * 3600)
        let status = DeadlineStatus.of(
            endDate: date(2026, 7, 21), leadDays: 3, now: noon, calendar: calendar
        )
        #expect(status == .active(daysRemaining: 14))
    }
}
