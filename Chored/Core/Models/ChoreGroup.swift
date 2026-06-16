import Foundation

/// A household / roommate group. Each group maps 1:1 to its own CloudKit
/// record zone (owner's private DB) and is shared to roommates via `CKShare`.
struct ChoreGroup: Identifiable, Equatable, Hashable, Codable {

    /// Stable identity = the group record's `recordName` (also the zone name).
    let id: String

    var name: String

    /// Record name of the iCloud user who created (owns) the group.
    let ownerRecordName: String

    /// Record names of all members, including the owner. Capped at 10.
    var memberRecordNames: [String]

    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        ownerRecordName: String,
        memberRecordNames: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerRecordName = ownerRecordName
        self.memberRecordNames = memberRecordNames
        self.createdAt = createdAt
    }

    func isOwner(_ recordName: String) -> Bool {
        ownerRecordName == recordName
    }

    /// Whether another member can still be added (respecting the cap).
    var canAddMember: Bool {
        memberRecordNames.count < Constants.Limits.membersPerGroup
    }
}
