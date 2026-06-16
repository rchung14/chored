import Foundation

/// Stores the local user's identity (record name + display name) in the App
/// Group suite so both the app and widget can read it. The display name is the
/// only PII persisted anywhere. No credentials are ever stored.
struct UserStore {

    private let defaults: UserDefaults

    init(suiteName: String = Constants.appGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    var displayName: String? {
        get { defaults.string(forKey: Constants.DefaultsKey.displayName) }
        nonmutating set { defaults.set(newValue, forKey: Constants.DefaultsKey.displayName) }
    }

    var userRecordName: String? {
        get { defaults.string(forKey: Constants.DefaultsKey.userRecordName) }
        nonmutating set { defaults.set(newValue, forKey: Constants.DefaultsKey.userRecordName) }
    }

    var didRequestNotifications: Bool {
        get { defaults.bool(forKey: Constants.DefaultsKey.didRequestNotifications) }
        nonmutating set { defaults.set(newValue, forKey: Constants.DefaultsKey.didRequestNotifications) }
    }

    var hasDisplayName: Bool {
        !(displayName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Cached map of member record names → display names, for rendering chips
    /// and notification copy without a round-trip. Best-effort only.
    func cachedName(for recordName: String) -> String? {
        let map = defaults.dictionary(forKey: "chored.nameCache") as? [String: String]
        return map?[recordName]
    }

    func cacheName(_ name: String, for recordName: String) {
        var map = defaults.dictionary(forKey: "chored.nameCache") as? [String: String] ?? [:]
        map[recordName] = name
        defaults.set(map, forKey: "chored.nameCache")
    }
}
