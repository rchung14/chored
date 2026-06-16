import Foundation
import SwiftData

/// Read/append task completion logs. Composes SwiftData + CloudKit. No SwiftUI.
@MainActor
protocol TaskLogRepositorying {
    /// Most recent logs for a task, newest first (default last 5).
    func recentLogs(forTask taskID: String, limit: Int) async -> [TaskLog]
    /// Append a log locally; `pendingSync` flags it for later CloudKit push.
    func append(_ log: TaskLog, pendingSync: Bool) async
}

@MainActor
final class TaskLogRepository: TaskLogRepositorying {

    private let container: ModelContainer
    private let cloud: CloudKitServicing

    init(container: ModelContainer, cloud: CloudKitServicing) {
        self.container = container
        self.cloud = cloud
    }

    private var context: ModelContext { container.mainContext }

    func recentLogs(forTask taskID: String, limit: Int = 5) async -> [TaskLog] {
        var descriptor = FetchDescriptor<SDTaskLog>(
            predicate: #Predicate { $0.taskID == taskID },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let local = (try? context.fetch(descriptor)) ?? []
        return local.map(\.domain)
    }

    func append(_ log: TaskLog, pendingSync: Bool) async {
        context.insert(SDTaskLog.make(from: log, pendingSync: pendingSync))
        try? context.save()
    }
}
