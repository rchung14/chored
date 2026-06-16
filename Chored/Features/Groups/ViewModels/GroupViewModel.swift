import Foundation
import Combine
import CloudKit

/// Drives the group list/detail/create flows. Depends on `GroupRepositorying`.
/// No SwiftUI/UIKit layout types — returns `CKShare` for the view to present.
@MainActor
final class GroupViewModel: ObservableObject {

    @Published private(set) var groups: [ChoreGroup] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let repository: GroupRepositorying
    private let currentUser: User

    init(repository: GroupRepositorying, currentUser: User) {
        self.repository = repository
        self.currentUser = currentUser
    }

    var canCreateGroup: Bool {
        groups.count < Constants.Limits.groupsPerUser
    }

    func load() async {
        isLoading = true
        groups = await repository.groups()
        isLoading = false
    }

    func createGroup(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            _ = try await repository.createGroup(
                name: trimmed, ownerRecordName: currentUser.recordName
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Prepares a `CKShare` for the view to hand to `UICloudSharingController`.
    func prepareShare(for group: ChoreGroup) async -> (CKShare, CKContainer)? {
        do {
            return try await repository.makeShare(for: group)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(_ group: ChoreGroup) async {
        do {
            try await repository.delete(group: group, currentUserRecordName: currentUser.recordName)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(_ group: ChoreGroup) async {
        do {
            try await repository.leave(group: group, currentUserRecordName: currentUser.recordName)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isOwner(_ group: ChoreGroup) -> Bool {
        group.isOwner(currentUser.recordName)
    }
}
