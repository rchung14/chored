import Foundation
import Combine

/// Backs the Tasks overview tab: upcoming tasks grouped by day, skipping days
/// that have no tasks. Depends on the task + group repositories. No SwiftUI.
@MainActor
final class TaskListViewModel: ObservableObject {

    /// A day that has at least one task, with its tasks.
    struct DaySection: Identifiable {
        let date: Date
        let tasks: [ChoreTask]
        var id: Date { date }
    }

    @Published private(set) var groups: [ChoreGroup] = []
    @Published var selectedGroupID: String?          // nil = all groups
    @Published private(set) var isLoading = false

    private var allTasks: [ChoreTask] = []

    /// How far ahead to scan for upcoming occurrences.
    private let horizonDays = 60

    private let taskRepository: TaskRepositorying
    private let groupRepository: GroupRepositorying
    private let userStore: UserStore
    private let currentUser: User

    init(
        taskRepository: TaskRepositorying,
        groupRepository: GroupRepositorying,
        userStore: UserStore,
        currentUser: User
    ) {
        self.taskRepository = taskRepository
        self.groupRepository = groupRepository
        self.userStore = userStore
        self.currentUser = currentUser
    }

    var hasGroups: Bool { !groups.isEmpty }

    func load() async {
        isLoading = true
        groups = await groupRepository.groups()
        allTasks = await taskRepository.allTasks(inGroups: groups.map(\.id))
        isLoading = false
    }

    func displayName(for recordName: String) -> String {
        if recordName == currentUser.recordName { return currentUser.displayName }
        return userStore.cachedName(for: recordName) ?? "Roommate"
    }

    func groupName(for groupID: String) -> String {
        groups.first { $0.id == groupID }?.name ?? ""
    }

    private var scopedTasks: [ChoreTask] {
        guard let id = selectedGroupID else { return allTasks }
        return allTasks.filter { $0.groupID == id }
    }

    /// Upcoming days (today forward) that have tasks, each capped per day.
    var sections: [DaySection] {
        let today = Date().startOfDay
        var result: [DaySection] = []
        for offset in 0..<horizonDays {
            let day = today.adding(days: offset)
            let dayTasks = scopedTasks
                .filter { $0.occurs(on: day) }
                .sorted { $0.name < $1.name }
            if !dayTasks.isEmpty {
                result.append(DaySection(
                    date: day,
                    tasks: Array(dayTasks.prefix(Constants.Limits.tasksPerGroupPerDay))
                ))
            }
        }
        return result
    }
}
