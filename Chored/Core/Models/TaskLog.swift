import Foundation

/// An immutable record of one task completion. Used for the detail-view history
/// and to drive roommate-facing remote pushes (a new TaskLog = someone did it).
struct TaskLog: Identifiable, Equatable, Hashable, Codable {

    let id: String
    let taskID: String
    let groupID: String
    let completedByRecordName: String
    let completedAt: Date

    init(
        id: String = UUID().uuidString,
        taskID: String,
        groupID: String,
        completedByRecordName: String,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.groupID = groupID
        self.completedByRecordName = completedByRecordName
        self.completedAt = completedAt
    }
}
