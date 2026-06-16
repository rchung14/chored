import Foundation

extension Date {

    /// Start of the calendar day in the current calendar/time zone.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Whether two dates fall on the same calendar day.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Adds whole days, preserving the time-of-day component.
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Weekday bit for the recurrence mask (Sunday = bit 0 ... Saturday = bit 6).
    var weekdayBit: Int {
        let weekday = Calendar.current.component(.weekday, from: self) // 1...7
        return 1 << (weekday - 1)
    }

    /// First moment of the month containing this date.
    var startOfMonth: Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: comps) ?? self
    }

    /// First moment of the year containing this date.
    var startOfYear: Date {
        let comps = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: comps) ?? self
    }

    /// Number of days in this date's month.
    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }
}
