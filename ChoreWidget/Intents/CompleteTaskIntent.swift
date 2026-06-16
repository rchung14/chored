import AppIntents
import WidgetKit

/// Marks a task complete directly from the widget, reusing the app's shared
/// completion flow. Optimistic local write first; CloudKit push handled inside
/// the repository (sets `pendingSync` on failure for the app to flush later).
struct CompleteTaskIntent: AppIntent {

    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark a chore complete from the home screen.")

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) { self.taskId = taskId }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = WidgetDataStore()
        guard let task = store.task(byID: taskId) else {
            return .result()
        }

        // 1–5: TaskRepository performs the full shared flow (write log, rotate /
        // advance, reschedule nudge, persist optimistically, push or pendingSync).
        let repository = store.makeTaskRepository()
        _ = try? await repository.completeTask(
            task,
            byUserRecordName: store.currentUserRecordName,
            displayName: { store.displayName(for: $0) }
        )

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
