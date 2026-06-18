import Foundation

/// Pure domain logic for tasks. Foundation only — no side effects, no I/O.
/// Kept in the model layer because Services are forbidden from holding business
/// logic and Repositories only orchestrate. These functions are unit-testable
/// in isolation and are reused by both the app and the widget completion flow.
extension ChoreTask {

    /// Whether this task is scheduled to appear on `day`.
    func occurs(on day: Date) -> Bool {
        let target = day.startOfDay

        if let excluded = excludedDates, excluded.contains(where: { $0.isSameDay(as: target) }) {
            return false
        }
        if target < startDate.startOfDay { return false }
        if let end = endDate, target > end.startOfDay { return false }

        guard isRecurring else {
            return target.isSameDay(as: startDate)
        }

        if let mask = weekdayMask {
            return (mask & target.weekdayBit) != 0
        }
        if let dates = recurringDates {
            return dates.contains { $0.isSameDay(as: target) }
        }
        // Recurring with no rule defined: only the start date.
        return target.isSameDay(as: startDate)
    }

    /// The next occurrence on or after `reference`, if any.
    func nextOccurrence(onOrAfter reference: Date) -> Date? {
        if let end = endDate, reference.startOfDay > end.startOfDay { return nil }

        guard isRecurring else {
            let start = startDate.startOfDay
            return start >= reference.startOfDay ? start : nil
        }

        if let dates = recurringDates {
            return dates
                .map(\.startOfDay)
                .filter { $0 >= reference.startOfDay }
                .filter { d in !(excludedDates?.contains { $0.isSameDay(as: d) } ?? false) }
                .min()
        }

        if weekdayMask != nil {
            var cursor = max(reference.startOfDay, startDate.startOfDay)
            // Scan up to a year ahead so excluded occurrences are skipped to the
            // next valid one; stop at the end date if there is one.
            for _ in 0..<366 {
                if let end = endDate, cursor > end.startOfDay { break }
                if occurs(on: cursor) { return cursor }
                cursor = cursor.adding(days: 1)
            }
        }
        return nil
    }

    /// The record name whose turn it is *after* the current assignee completes.
    /// Returns the current assignee unchanged when the task does not alternate.
    func nextAssigneeRecordName() -> String {
        guard isAlternating, !alternatingOrder.isEmpty else {
            return assigneeRecordName
        }
        let idx = alternatingOrder.firstIndex(of: assigneeRecordName) ?? -1
        let next = (idx + 1) % alternatingOrder.count
        return alternatingOrder[next]
    }

    /// Returns a copy of this task transformed by a completion at `date`.
    ///
    /// Order matches the COMPLETE TASK FLOW spec:
    /// 1. mark complete + stamp time
    /// 2. alternating → rotate assignee
    /// 3. recurring → reopen and advance to next occurrence
    func completed(at date: Date = Date()) -> ChoreTask {
        var copy = self
        copy.isComplete = true
        copy.completedAt = date

        if isAlternating {
            copy.assigneeRecordName = nextAssigneeRecordName()
        }

        if isRecurring {
            copy.isComplete = false
            copy.completedAt = nil
            if let next = nextOccurrence(onOrAfter: date.adding(days: 1)) {
                copy.startDate = next
            }
        }
        return copy
    }
}
