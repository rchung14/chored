import SwiftUI

/// Month grid with per-day task-color dots (≤3 then "+N"). Tap a day → Day view.
struct MonthView: View {

    @ObservedObject var viewModel: CalendarViewModel
    let onSelectDay: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    private var presetsByDay: [Date: [Int]] { viewModel.presets(forDaysIn: viewModel.selectedDate) }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            monthHeader
            weekdayRow
            grid
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
            Spacer()
            Text(viewModel.selectedDate.formatted(.dateTime.month(.wide)))
                .choredTitle2()
                .foregroundStyle(Color(.label))
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .choredCaption()
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 44) }
            ForEach(daysInMonth, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let presets = presetsByDay[day.startOfDay] ?? []
        return Button {
            viewModel.selectedDate = day
            onSelectDay()
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .choredSubheadline()
                    .foregroundStyle(isToday(day) ? Color(.systemBackground) : Color(.label))
                    .frame(width: 28, height: 28)
                    .background(isToday(day) ? Color(.label) : .clear)
                    .clipShape(Circle())
                dotRow(presets)
                    .frame(height: Theme.Size.monthDot)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dotRow(_ presets: [Int]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(presets.prefix(Constants.Limits.monthDotCap).enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(TaskColorPreset.from(index: p).background(for: scheme))
                    .frame(width: Theme.Size.monthDot, height: Theme.Size.monthDot)
            }
            if presets.count > Constants.Limits.monthDotCap {
                Text("+\(presets.count - Constants.Limits.monthDotCap)")
                    .choredCaption2()
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    @Environment(\.colorScheme) private var scheme

    // MARK: Date math

    private var daysInMonth: [Date] {
        let start = viewModel.selectedDate.startOfMonth
        return (0..<viewModel.selectedDate.daysInMonth).map { start.adding(days: $0) }
    }

    private var leadingBlanks: Int {
        let first = viewModel.selectedDate.startOfMonth
        return Calendar.current.component(.weekday, from: first) - 1
    }

    private func isToday(_ day: Date) -> Bool { day.isSameDay(as: Date()) }

    private func shiftMonth(_ delta: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: delta, to: viewModel.selectedDate) {
            viewModel.selectedDate = new
        }
    }
}
