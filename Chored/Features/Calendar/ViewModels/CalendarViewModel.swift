import Foundation
import Combine

/// Aggregates tasks across the user's groups for the calendar's Day/Month/Year
/// views. Depends on the task + group repositories. No SwiftUI/UIKit types.
@MainActor
final class CalendarViewModel: ObservableObject {

    @Published private(set) var groups: [ChoreGroup] = []
    @Published var selectedGroupID: String?      // nil = all groups
    @Published var selectedDate: Date = Date()
    @Published private(set) var isLoading = false

    private var allTasks: [ChoreTask] = []

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

    /// The group new tasks should be created in (explicit selection or first).
    var creationGroup: ChoreGroup? {
        if let id = selectedGroupID { return groups.first { $0.id == id } }
        return groups.first
    }

    func load() async {
        isLoading = true
        groups = await groupRepository.groups()
        let ids = groups.map(\.id)
        allTasks = await taskRepository.allTasks(inGroups: ids)
        isLoading = false
    }

    func displayName(for recordName: String) -> String {
        if recordName == currentUser.recordName { return currentUser.displayName }
        return userStore.cachedName(for: recordName) ?? "Roommate"
    }

    private var scopedTasks: [ChoreTask] {
        guard let id = selectedGroupID else { return allTasks }
        return allTasks.filter { $0.groupID == id }
    }

    /// Tasks occurring on `day`, honoring the 20-per-group-per-day cap.
    func tasks(on day: Date) -> [ChoreTask] {
        let occurring = scopedTasks.filter { $0.occurs(on: day) }
        let byGroup = Dictionary(grouping: occurring, by: \.groupID)
        var result: [ChoreTask] = []
        for (_, tasks) in byGroup {
            result += tasks
                .sorted { $0.name < $1.name }
                .prefix(Constants.Limits.tasksPerGroupPerDay)
        }
        return result.sorted { $0.name < $1.name }
    }

    /// Color presets for each day in the month containing `month`.
    func presets(forDaysIn month: Date) -> [Date: [Int]] {
        var map: [Date: [Int]] = [:]
        let start = month.startOfMonth
        for offset in 0..<month.daysInMonth {
            let day = start.adding(days: offset).startOfDay
            let presets = tasks(on: day).map(\.colorPreset)
            if !presets.isEmpty { map[day] = presets }
        }
        return map
    }

    /// Task-count density per month for the year containing `year`.
    func density(forMonthsIn year: Date) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        let cal = Calendar.current
        let startOfYear = year.startOfYear
        for monthIndex in 0..<12 {
            guard let monthDate = cal.date(byAdding: .month, value: monthIndex, to: startOfYear) else { continue }
            var total = 0
            for dayOffset in 0..<monthDate.daysInMonth {
                total += tasks(on: monthDate.startOfMonth.adding(days: dayOffset)).count
            }
            counts[monthIndex + 1] = total
        }
        return counts
    }
}
