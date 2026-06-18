import SwiftUI

/// Tasks overview tab: upcoming tasks grouped by day, skipping empty days, so
/// you can see at a glance what's coming up and when (today, tomorrow, …).
struct TaskListView: View {

    let currentUser: User
    private let container: AppContainer
    @StateObject private var viewModel: TaskListViewModel
    @StateObject private var taskVM: TaskViewModel

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: TaskListViewModel(
            taskRepository: container.taskRepository,
            groupRepository: container.groupRepository,
            userStore: container.userStore,
            currentUser: currentUser
        ))
        _taskVM = StateObject(wrappedValue: TaskViewModel(
            taskRepository: container.taskRepository,
            logRepository: container.logRepository,
            userStore: container.userStore,
            currentUser: currentUser
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sections.isEmpty {
                    EmptyStateView(
                        systemImage: "checklist",
                        message: viewModel.hasGroups
                            ? "No upcoming tasks — add one from the calendar."
                            : "Join or create a group to start adding tasks."
                    )
                } else {
                    listContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    brandHeader
                    if viewModel.groups.count > 1 {
                        GroupFilterMenu(
                            options: viewModel.groups.map { .init(id: $0.id, name: $0.name) },
                            selectedID: $viewModel.selectedGroupID
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Color(.systemBackground))
            }
            .task { await viewModel.load() }
        }
    }

    /// Chored wordmark + current date (the page's brand header).
    private var brandHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checklist")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color(.label))
            VStack(alignment: .leading, spacing: 2) {
                Text("Chored")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color(.label))
                Text(Date().formatted(date: .complete, time: .omitted))
                    .choredSubheadline()
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chored, \(Date().formatted(date: .complete, time: .omitted))")
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.tasks) { task in
                        NavigationLink {
                            TaskDetailView(
                                task: task,
                                group: viewModel.groups.first { $0.id == task.groupID },
                                occurrenceDate: section.date,
                                viewModel: taskVM
                            )
                        } label: {
                            TaskChipView(
                                task: task,
                                assigneeName: viewModel.displayName(for: task.assigneeRecordName)
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.md,
                                                  bottom: Theme.Spacing.xs, trailing: Theme.Spacing.md))
                    }
                } header: {
                    Text(header(for: section.date))
                        .choredSubheadline()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .listStyle(.plain)
    }

    private func header(for date: Date) -> String {
        if date.isSameDay(as: Date()) { return "Today" }
        if date.isSameDay(as: Date().adding(days: 1)) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
