import Foundation
import CloudKit

/// Group operations. Composes the local store + CloudKit. Returns domain models.
/// No SwiftUI. Enforces the ≤5 groups / ≤10 members client-side caps.
@MainActor
protocol GroupRepositorying {
    func groups() async -> [ChoreGroup]
    func createGroup(name: String, ownerRecordName: String) async throws -> ChoreGroup
    func makeShare(for group: ChoreGroup) async throws -> (CKShare, CKContainer)
    func leave(group: ChoreGroup, currentUserRecordName: String) async throws
    func delete(group: ChoreGroup, currentUserRecordName: String) async throws
}

enum GroupRepositoryError: LocalizedError {
    case groupLimitReached
    case memberLimitReached
    case notOwner

    var errorDescription: String? {
        switch self {
        case .groupLimitReached: return "You can be in up to \(Constants.Limits.groupsPerUser) groups."
        case .memberLimitReached: return "A group can have up to \(Constants.Limits.membersPerGroup) members."
        case .notOwner: return "Only the group owner can delete this group."
        }
    }
}

@MainActor
final class GroupRepository: GroupRepositorying {

    private let cloud: CloudKitServicing
    private let store: GroupStore

    init(cloud: CloudKitServicing, store: GroupStore = GroupStore()) {
        self.cloud = cloud
        self.store = store
    }

    func groups() async -> [ChoreGroup] {
        // Local store is authoritative for offline; merge in CloudKit results.
        var merged: [String: ChoreGroup] = [:]
        for g in store.load() { merged[g.id] = g }
        if let remote = try? await cloud.fetchGroups() {
            for g in remote { merged[g.id] = g }
            store.save(Array(merged.values))
        }
        return merged.values.sorted { $0.createdAt < $1.createdAt }
    }

    func createGroup(name: String, ownerRecordName: String) async throws -> ChoreGroup {
        let existing = store.load()
        guard existing.count < Constants.Limits.groupsPerUser else {
            throw GroupRepositoryError.groupLimitReached
        }

        let group = ChoreGroup(
            name: name,
            ownerRecordName: ownerRecordName,
            memberRecordNames: [ownerRecordName]
        )

        // Persist locally first (works offline), then attempt CloudKit.
        store.upsert(group)
        if case .available = await cloud.availability() {
            try? await cloud.createZone(named: group.id)
            let saved = (try? await cloud.save(group: group)) ?? group
            try? await cloud.registerSubscriptions(forGroup: group.id)
            store.upsert(saved)
            return saved
        }
        return group
    }

    func makeShare(for group: ChoreGroup) async throws -> (CKShare, CKContainer) {
        guard group.canAddMember else { throw GroupRepositoryError.memberLimitReached }
        return try await cloud.share(forGroup: group)
    }

    func leave(group: ChoreGroup, currentUserRecordName: String) async throws {
        // Removing self from the share is handled by the system sharing UI for
        // joined groups; locally we just drop it from this device's list.
        store.remove(id: group.id)
    }

    func delete(group: ChoreGroup, currentUserRecordName: String) async throws {
        guard group.isOwner(currentUserRecordName) else {
            throw GroupRepositoryError.notOwner
        }
        store.remove(id: group.id)
        if case .available = await cloud.availability() {
            try? await cloud.deleteZone(named: group.id)
        }
    }
}
