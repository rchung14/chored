import SwiftUI
import UIKit

/// Scrollable list of task chips for the selected day, with day navigation.
struct DayView: View {

    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    private var tasks: [ChoreTask] { viewModel.tasks(on: viewModel.selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            if tasks.isEmpty {
                EmptyStateView(systemImage: "checkmark.circle", message: "No tasks today — add one with +")
            } else {
                taskList
            }
        }
    }

    private var dayHeader: some View {
        HStack {
            Button { shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
            Spacer()
            VStack(spacing: Theme.Spacing.xs) {
                Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide)))
                    .choredSubheadline()
                    .foregroundStyle(Color(.secondaryLabel))
                Text(viewModel.selectedDate.formatted(.dateTime.day().month(.abbreviated)))
                    .choredTitle3()
                    .foregroundStyle(Color(.label))
            }
            Spacer()
            Button { shiftDay(1) } label: { Image(systemName: "chevron.right") }
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var taskList: some View {
        List {
            ForEach(tasks) { task in
                NavigationLink {
                    TaskDetailView(
                        task: task,
                        group: viewModel.groups.first { $0.id == task.groupID },
                        occurrenceDate: viewModel.selectedDate,
                        viewModel: taskViewModel
                    )
                } label: {
                    TaskChipView(task: task, assigneeName: viewModel.displayName(for: task.assigneeRecordName))
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.md,
                                          bottom: Theme.Spacing.xs, trailing: Theme.Spacing.md))
                .swipeActions(edge: .leading) {
                    // Only the assigned roommate can complete their task.
                    if !task.isComplete && taskViewModel.canComplete(task) {
                        Button { complete(task) } label: { Label("Done", systemImage: "checkmark") }
                            .tint(Color(.systemBlue))
                    }
                }
                .swipeActions(edge: .trailing) {
                    if taskViewModel.canDelete(task, group: viewModel.groups.first { $0.id == task.groupID }) {
                        Button(role: .destructive) { delete(task) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: tasks)
    }

    private func shiftDay(_ delta: Int) {
        viewModel.selectedDate = viewModel.selectedDate.adding(days: delta)
    }

    private func complete(_ task: ChoreTask) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { _ = await taskViewModel.complete(task); await viewModel.load() }
    }

    private func delete(_ task: ChoreTask) {
        Task { await taskViewModel.delete(task); await viewModel.load() }
    }
}
