import SwiftUI

/// Domain-aware wrapper that maps a `ChoreTask` to the design-system `ChoreChip`.
struct TaskChipView: View {
    let task: ChoreTask
    let assigneeName: String

    var body: some View {
        ChoreChip(
            name: task.name,
            assigneeName: assigneeName,
            assigneeInitials: User(recordName: "", displayName: assigneeName).initials,
            metadata: metadata,
            preset: TaskColorPreset.from(index: task.colorPreset)
        )
        .opacity(task.isComplete ? 0.5 : 1.0)
    }

    private var metadata: String {
        if task.isComplete { return "Done" }
        if task.isAlternating { return "Alternating" }
        if task.isRecurring { return "Recurring" }
        return "Due today"
    }
}
