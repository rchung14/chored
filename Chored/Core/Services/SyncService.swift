import Foundation
import SwiftData

/// Reconciles CloudKit with the local SwiftData store. Side effects only.
///
/// Degrades to a no-op when iCloud is unavailable so the app runs fully
/// local-only. Push of offline/widget completions is driven by `pendingSync`.
protocol SyncServicing {
    func pull() async
    func flushPending() async
    func sync() async
}

final class SyncService: SyncServicing {

    private let cloud: CloudKitServicing
    private let container: ModelContainer

    init(cloud: CloudKitServicing, container: ModelContainer) {
        self.cloud = cloud
        self.container = container
    }

    func sync() async {
        await flushPending()
        await pull()
    }

    // MARK: - Pull (CloudKit -> SwiftData)

    func pull() async {
        guard case .available = await cloud.availability() else { return }
        guard let groups = try? await cloud.fetchGroups() else { return }

        let context = ModelContext(container)
        for group in groups {
            if let tasks = try? await cloud.fetchTasks(inGroup: group.id) {
                for task in tasks { upsert(task, in: context) }
            }
            for task in (try? await cloud.fetchTasks(inGroup: group.id)) ?? [] {
                if let logs = try? await cloud.fetchLogs(forTask: task.id, inGroup: group.id) {
                    for log in logs { upsert(log, in: context) }
                }
            }
        }
        try? context.save()
    }

    private func upsert(_ task: ChoreTask, in context: ModelContext) {
        let id = task.id
        let descriptor = FetchDescriptor<SDChoreTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            // Never clobber a local mutation that hasn't been pushed yet.
            guard !existing.pendingSync else { return }
            existing.apply(task, pendingSync: false)
        } else {
            context.insert(SDChoreTask.make(from: task, pendingSync: false))
        }
    }

    private func upsert(_ log: TaskLog, in context: ModelContext) {
        let id = log.id
        let descriptor = FetchDescriptor<SDTaskLog>(
            predicate: #Predicate { $0.id == id }
        )
        if (try? context.fetch(descriptor).first) == nil {
            context.insert(SDTaskLog.make(from: log, pendingSync: false))
        }
    }

    // MARK: - Push (pending SwiftData -> CloudKit)

    func flushPending() async {
        guard case .available = await cloud.availability() else { return }
        let context = ModelContext(container)

        let pendingLogs = (try? context.fetch(
            FetchDescriptor<SDTaskLog>(predicate: #Predicate { $0.pendingSync })
        )) ?? []
        for sdLog in pendingLogs {
            if (try? await cloud.save(log: sdLog.domain)) != nil {
                sdLog.pendingSync = false
            }
        }

        let pendingTasks = (try? context.fetch(
            FetchDescriptor<SDChoreTask>(predicate: #Predicate { $0.pendingSync })
        )) ?? []
        for sdTask in pendingTasks {
            if (try? await cloud.save(task: sdTask.domain)) != nil {
                sdTask.pendingSync = false
            }
        }

        try? context.save()
    }
}
