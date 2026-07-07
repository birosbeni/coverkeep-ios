import Foundation
import SwiftUI

/// Where a coverage stands today, with the unambiguous chip semantics from
/// the design direction: green active → amber expiring → gray expired.
/// "Expiring" begins inside the coverage's own reminder lead window, so the
/// chip and the reminder always agree.
enum DeadlineStatus: Equatable {
    case active(daysRemaining: Int)
    case expiringSoon(daysRemaining: Int)
    case expired

    /// `endDate` is the coverage's inclusive last day; day counting is civil
    /// (start-of-day to start-of-day) via `Calendar`, never interval math.
    static func of(
        endDate: Date,
        leadDays: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DeadlineStatus {
        let today = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: endDate)
        guard let days = calendar.dateComponents([.day], from: today, to: end).day else {
            preconditionFailure("Calendar failed to count days from \(today) to \(end)")
        }
        if days < 0 {
            return .expired
        }
        if days <= leadDays {
            return .expiringSoon(daysRemaining: days)
        }
        return .active(daysRemaining: days)
    }

    var tint: Color {
        switch self {
        case .active: .green
        case .expiringSoon: .orange
        case .expired: .gray
        }
    }

    var label: String {
        switch self {
        case .active(let days), .expiringSoon(let days):
            if days == 0 {
                return String(localized: "Ends today")
            }
            return String(localized: "\(days) days left")
        case .expired:
            return String(localized: "Expired")
        }
    }
}
