import Foundation

/// Local persistence for `ChoreGroup` in the App Group's UserDefaults suite.
///
/// SwiftData is scoped to tasks + logs (per spec), but groups still need a
/// local home so the app is fully usable with zero CloudKit access. Groups are
/// small and few (≤5), so JSON-in-UserDefaults is sufficient and avoids adding
/// them to the SwiftData schema.
struct GroupStore {

    private let defaults: UserDefaults
    private let key = "chored.groups.v1"

    init(suiteName: String = Constants.appGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func load() -> [ChoreGroup] {
        guard let data = defaults.data(forKey: key),
              let groups = try? JSONDecoder().decode([ChoreGroup].self, from: data) else {
            return []
        }
        return groups
    }

    func save(_ groups: [ChoreGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: key)
    }

    func upsert(_ group: ChoreGroup) {
        var all = load()
        if let idx = all.firstIndex(where: { $0.id == group.id }) {
            all[idx] = group
        } else {
            all.append(group)
        }
        save(all)
    }

    func remove(id: String) {
        save(load().filter { $0.id != id })
    }
}
