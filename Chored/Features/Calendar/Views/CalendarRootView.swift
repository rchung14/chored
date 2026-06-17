import SwiftUI

/// Segmented Day | Month container. Hosts the FAB and task-creation sheet, and
/// owns the calendar + task view models.
struct CalendarRootView: View {

    let currentUser: User
    @StateObject private var calendarVM: CalendarViewModel
    @StateObject private var taskVM: TaskViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case day = "Day", month = "Month"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .day
    @State private var showingCreate = false

    init(container: AppContainer, currentUser: User) {
        self.currentUser = currentUser
        _calendarVM = StateObject(wrappedValue: CalendarViewModel(
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
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: Theme.Spacing.md) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.md)

                    if calendarVM.groups.count > 1 {
                        GroupFilterMenu(
                            options: calendarVM.groups.map { .init(id: $0.id, name: $0.name) },
                            selectedID: $calendarVM.selectedGroupID
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    content
                }
                .padding(.top, Theme.Spacing.sm)

                if calendarVM.hasGroups {
                    FABButton { showingCreate = true }
                        .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreate) {
                if !calendarVM.groups.isEmpty {
                    TaskCreationView(
                        groups: calendarVM.groups,
                        defaultGroupID: calendarVM.selectedGroupID,
                        currentUser: currentUser,
                        defaultDate: calendarVM.selectedDate,
                        viewModel: taskVM
                    )
                    .onDisappear { Task { await calendarVM.load() } }
                }
            }
            .task { await calendarVM.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !calendarVM.hasGroups {
            EmptyStateView(
                systemImage: "calendar",
                message: "Join or create a group to start adding tasks."
            )
        } else {
            switch mode {
            case .day:
                DayView(viewModel: calendarVM, taskViewModel: taskVM)
            case .month:
                MonthView(viewModel: calendarVM) { mode = .day }
            }
        }
    }

    private var navTitle: String {
        switch mode {
        case .day: return calendarVM.selectedDate.formatted(date: .abbreviated, time: .omitted)
        case .month: return calendarVM.selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }
}
