import Foundation

/// A Chored user, identified by their iCloud user record name.
///
/// Pure domain model — wraps the stable CloudKit record-name string plus a
/// human-readable display name. No CloudKit types leak into this layer so the
/// model can be used offline and in the widget without importing CloudKit.
struct User: Identifiable, Equatable, Hashable, Codable {

    /// The CloudKit `CKRecord.ID.recordName` for this user. Stable identity.
    let recordName: String

    /// Name shown throughout the UI. Prompted once on first launch.
    var displayName: String

    var id: String { recordName }

    init(recordName: String, displayName: String) {
        self.recordName = recordName
        self.displayName = displayName
    }

    /// Up to two uppercase initials derived from `displayName`, for avatars.
    var initials: String {
        let parts = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let result = String(parts).uppercased()
        return result.isEmpty ? "?" : result
    }
}
