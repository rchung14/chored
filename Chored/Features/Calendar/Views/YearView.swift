import SwiftUI

/// Year overview as a density heatmap. systemBlue opacity encodes task density;
/// task colors are intentionally not used here. Tap a month → Month view.
struct YearView: View {

    @ObservedObject var viewModel: CalendarViewModel
    let onSelectMonth: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.md), count: 3)
    private let monthSymbols = Calendar.current.shortMonthSymbols

    /// Density saturates at this many tasks (= 100% opacity).
    private let densityCeiling = 5.0

    private var density: [Int: Int] { viewModel.density(forMonthsIn: viewModel.selectedDate) }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            yearHeader
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(1...12, id: \.self) { month in
                    monthTile(month)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var yearHeader: some View {
        HStack {
            Button { shiftYear(-1) } label: { Image(systemName: "chevron.left") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
            Spacer()
            Text(viewModel.selectedDate.formatted(.dateTime.year()))
                .choredTitle2()
                .foregroundStyle(Color(.label))
            Spacer()
            Button { shiftYear(1) } label: { Image(systemName: "chevron.right") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
        }
    }

    private func monthTile(_ month: Int) -> some View {
        let count = density[month] ?? 0
        let opacity = min(1.0, Double(count) / densityCeiling)
        return Button {
            selectMonth(month)
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .fill(Color(.systemBlue).opacity(opacity))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }
                    .frame(height: 56)
                Text(monthSymbols[month - 1])
                    .choredCaption()
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(monthSymbols[month - 1]), \(count) tasks")
    }

    private func selectMonth(_ month: Int) {
        var comps = Calendar.current.dateComponents([.year], from: viewModel.selectedDate)
        comps.month = month
        comps.day = 1
        if let date = Calendar.current.date(from: comps) {
            viewModel.selectedDate = date
            onSelectMonth()
        }
    }

    private func shiftYear(_ delta: Int) {
        if let new = Calendar.current.date(byAdding: .year, value: delta, to: viewModel.selectedDate) {
            viewModel.selectedDate = new
        }
    }
}
