import Foundation
import CloudKit

/// Availability of the user's iCloud account, surfaced to the UI so it can show
/// the "Sign in to iCloud" blocking screen and gate sync features.
enum CloudAvailability: Equatable {
    case available(userRecordName: String)
    case noAccount
    case restricted
    case unknown
}

/// Errors that callers may need to distinguish. CloudKit's own errors are
/// otherwise passed through unmodified.
enum CloudKitError: Error {
    case unavailable
    case missingUserRecord
    case shareCreationFailed
}

/// CloudKit side-effect boundary. CRUD, zones, sharing, subscriptions.
/// No business logic lives here — callers (repositories) compose these calls.
/// Every method must fail gracefully (throw, never crash) when iCloud is off.
protocol CloudKitServicing {

    /// Current iCloud availability and the user's stable record name.
    func availability() async -> CloudAvailability

    // Zones / groups
    func createZone(named name: String) async throws
    func deleteZone(named name: String) async throws
    func save(group: ChoreGroup) async throws -> ChoreGroup
    func fetchGroups() async throws -> [ChoreGroup]

    // Tasks
    func save(task: ChoreTask) async throws -> ChoreTask
    func delete(taskID: String, inGroup groupID: String) async throws
    func fetchTasks(inGroup groupID: String) async throws -> [ChoreTask]

    // Logs
    func save(log: TaskLog) async throws -> TaskLog
    func fetchLogs(forTask taskID: String, inGroup groupID: String) async throws -> [TaskLog]

    // Sharing
    /// Returns an existing or freshly-created `CKShare` for the group's zone,
    /// plus the container, ready to hand to `UICloudSharingController`.
    func share(forGroup group: ChoreGroup) async throws -> (CKShare, CKContainer)

    // Subscriptions (roommate-driven push)
    func registerSubscriptions(forGroup groupID: String) async throws
}

/// Concrete CloudKit implementation.
final class CloudKitService: CloudKitServicing {

    private let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    init(containerID: String = Constants.cloudContainerID) {
        self.container = CKContainer(identifier: containerID)
    }

    // MARK: - Availability

    func availability() async -> CloudAvailability {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if let id = try? await container.userRecordID() {
                    return .available(userRecordName: id.recordName)
                }
                return .unknown
            case .noAccount:
                return .noAccount
            case .restricted, .temporarilyUnavailable:
                return .restricted
            default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private func requireUserRecordName() async throws -> String {
        guard case let .available(name) = await availability() else {
            throw CloudKitError.unavailable
        }
        return name
    }

    private func zoneID(_ name: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: name, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Zones

    func createZone(named name: String) async throws {
        _ = try await requireUserRecordName()
        let zone = CKRecordZone(zoneID: zoneID(name))
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
    }

    func deleteZone(named name: String) async throws {
        _ = try await requireUserRecordName()
        _ = try await privateDB.modifyRecordZones(saving: [], deleting: [zoneID(name)])
    }

    // MARK: - Groups

    func save(group: ChoreGroup) async throws -> ChoreGroup {
        _ = try await requireUserRecordName()
        let record = CKRecord(
            recordType: Constants.RecordType.group,
            recordID: CKRecord.ID(recordName: group.id, zoneID: zoneID(group.id))
        )
        record["name"] = group.name as CKRecordValue
        record["ownerRecordName"] = group.ownerRecordName as CKRecordValue
        record["memberRecordNames"] = group.memberRecordNames as CKRecordValue
        record["createdAt"] = group.createdAt as CKRecordValue
        let saved = try await privateDB.save(record)
        return Self.group(from: saved) ?? group
    }

    func fetchGroups() async throws -> [ChoreGroup] {
        _ = try await requireUserRecordName()
        var groups: [ChoreGroup] = []
        groups += try await fetchGroups(in: privateDB)
        groups += try await fetchGroups(in: sharedDB)
        return groups
    }

    private func fetchGroups(in db: CKDatabase) async throws -> [ChoreGroup] {
        let zones = try await db.allRecordZones()
        var result: [ChoreGroup] = []
        for zone in zones where zone.zoneID.zoneName != CKRecordZone.ID.defaultZoneName {
            let query = CKQuery(
                recordType: Constants.RecordType.group,
                predicate: NSPredicate(value: true)
            )
            let (matches, _) = try await db.records(
                matching: query, inZoneWith: zone.zoneID
            )
            for (_, recordResult) in matches {
                if case let .success(record) = recordResult,
                   let group = Self.group(from: record) {
                    result.append(group)
                }
            }
        }
        return result
    }

    // MARK: - Tasks

    func save(task: ChoreTask) async throws -> ChoreTask {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: task.groupID)
        let record = CKRecord(
            recordType: Constants.RecordType.task,
            recordID: CKRecord.ID(recordName: task.id, zoneID: zoneID(task.groupID))
        )
        Self.populate(record, from: task)
        let saved = try await db.save(record)
        return Self.task(from: saved) ?? task
    }

    func delete(taskID: String, inGroup groupID: String) async throws {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: groupID)
        let id = CKRecord.ID(recordName: taskID, zoneID: zoneID(groupID))
        _ = try await db.deleteRecord(withID: id)
    }

    func fetchTasks(inGroup groupID: String) async throws -> [ChoreTask] {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: groupID)
        let query = CKQuery(
            recordType: Constants.RecordType.task,
            predicate: NSPredicate(value: true)
        )
        let (matches, _) = try await db.records(
            matching: query, inZoneWith: zoneID(groupID)
        )
        return matches.compactMap { _, result in
            if case let .success(record) = result { return Self.task(from: record) }
            return nil
        }
    }

    // MARK: - Logs

    func save(log: TaskLog) async throws -> TaskLog {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: log.groupID)
        let record = CKRecord(
            recordType: Constants.RecordType.taskLog,
            recordID: CKRecord.ID(recordName: log.id, zoneID: zoneID(log.groupID))
        )
        record["taskID"] = log.taskID as CKRecordValue
        record["groupID"] = log.groupID as CKRecordValue
        record["completedByRecordName"] = log.completedByRecordName as CKRecordValue
        record["completedAt"] = log.completedAt as CKRecordValue
        let saved = try await db.save(record)
        return Self.log(from: saved) ?? log
    }

    func fetchLogs(forTask taskID: String, inGroup groupID: String) async throws -> [TaskLog] {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: groupID)
        let predicate = NSPredicate(format: "taskID == %@", taskID)
        let query = CKQuery(recordType: Constants.RecordType.taskLog, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        let (matches, _) = try await db.records(
            matching: query, inZoneWith: zoneID(groupID)
        )
        return matches.compactMap { _, result in
            if case let .success(record) = result { return Self.log(from: record) }
            return nil
        }
    }

    // MARK: - Sharing

    func share(forGroup group: ChoreGroup) async throws -> (CKShare, CKContainer) {
        _ = try await requireUserRecordName()
        let zone = zoneID(group.id)

        // Reuse an existing zone-wide share if present.
        if let existing = try? await fetchExistingShare(in: zone) {
            return (existing, container)
        }

        let share = CKShare(recordZoneID: zone)
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue
        share.publicPermission = .none
        let result = try await privateDB.modifyRecords(saving: [share], deleting: [])
        guard case .success = result.saveResults[share.recordID] else {
            throw CloudKitError.shareCreationFailed
        }
        return (share, container)
    }

    private func fetchExistingShare(in zone: CKRecordZone.ID) async throws -> CKShare? {
        let recordZone = try await privateDB.recordZone(for: zone)
        guard let shareReference = recordZone.share else { return nil }
        let record = try await privateDB.record(for: shareReference.recordID)
        return record as? CKShare
    }

    // MARK: - Subscriptions

    func registerSubscriptions(forGroup groupID: String) async throws {
        _ = try await requireUserRecordName()
        let db = try await database(forGroup: groupID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // silent push; client refetches

        let logSub = CKQuerySubscription(
            recordType: Constants.RecordType.taskLog,
            predicate: NSPredicate(value: true),
            subscriptionID: "log-\(groupID)",
            options: [.firesOnRecordCreation]
        )
        logSub.notificationInfo = info

        let taskSub = CKQuerySubscription(
            recordType: Constants.RecordType.task,
            predicate: NSPredicate(value: true),
            subscriptionID: "task-\(groupID)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        taskSub.notificationInfo = info

        _ = try await db.modifySubscriptions(saving: [logSub, taskSub], deleting: [])
    }

    // MARK: - Helpers

    /// Resolve which database a group's zone lives in (private if owned,
    /// shared if joined). Defaults to private when not found in shared.
    private func database(forGroup groupID: String) async throws -> CKDatabase {
        if let zones = try? await sharedDB.allRecordZones(),
           zones.contains(where: { $0.zoneID.zoneName == groupID }) {
            return sharedDB
        }
        return privateDB
    }

    // MARK: - Record mapping

    private static func populate(_ record: CKRecord, from task: ChoreTask) {
        record["groupID"] = task.groupID as CKRecordValue
        record["name"] = task.name as CKRecordValue
        record["taskDescription"] = task.description as CKRecordValue
        record["colorPreset"] = task.colorPreset as CKRecordValue
        record["assigneeRecordName"] = task.assigneeRecordName as CKRecordValue
        record["isRecurring"] = (task.isRecurring ? 1 : 0) as CKRecordValue
        record["weekdayMask"] = task.weekdayMask as CKRecordValue?
        record["recurringDates"] = task.recurringDates as CKRecordValue?
        record["isAlternating"] = (task.isAlternating ? 1 : 0) as CKRecordValue
        record["alternatingOrder"] = task.alternatingOrder as CKRecordValue
        record["startDate"] = task.startDate as CKRecordValue
        record["endDate"] = task.endDate as CKRecordValue?
        record["estimatedIntervalDays"] = task.estimatedIntervalDays as CKRecordValue?
        record["isComplete"] = (task.isComplete ? 1 : 0) as CKRecordValue
        record["completedAt"] = task.completedAt as CKRecordValue?
    }

    private static func group(from record: CKRecord) -> ChoreGroup? {
        guard let name = record["name"] as? String,
              let owner = record["ownerRecordName"] as? String else { return nil }
        return ChoreGroup(
            id: record.recordID.recordName,
            name: name,
            ownerRecordName: owner,
            memberRecordNames: record["memberRecordNames"] as? [String] ?? [owner],
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }

    private static func task(from record: CKRecord) -> ChoreTask? {
        guard let groupID = record["groupID"] as? String,
              let name = record["name"] as? String,
              let assignee = record["assigneeRecordName"] as? String else { return nil }
        return ChoreTask(
            id: record.recordID.recordName,
            groupID: groupID,
            name: name,
            description: record["taskDescription"] as? String ?? "",
            colorPreset: record["colorPreset"] as? Int ?? 0,
            assigneeRecordName: assignee,
            isRecurring: (record["isRecurring"] as? Int ?? 0) == 1,
            weekdayMask: record["weekdayMask"] as? Int,
            recurringDates: record["recurringDates"] as? [Date],
            isAlternating: (record["isAlternating"] as? Int ?? 0) == 1,
            alternatingOrder: record["alternatingOrder"] as? [String] ?? [],
            startDate: record["startDate"] as? Date ?? Date(),
            endDate: record["endDate"] as? Date,
            estimatedIntervalDays: record["estimatedIntervalDays"] as? Int,
            isComplete: (record["isComplete"] as? Int ?? 0) == 1,
            completedAt: record["completedAt"] as? Date
        )
    }

    private static func log(from record: CKRecord) -> TaskLog? {
        guard let taskID = record["taskID"] as? String,
              let groupID = record["groupID"] as? String,
              let by = record["completedByRecordName"] as? String,
              let at = record["completedAt"] as? Date else { return nil }
        return TaskLog(
            id: record.recordID.recordName,
            taskID: taskID,
            groupID: groupID,
            completedByRecordName: by,
            completedAt: at
        )
    }
}
