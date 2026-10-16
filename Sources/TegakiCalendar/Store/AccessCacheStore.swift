import Access
import Foundation

/// Where the last confirmed access state is kept between launches (M5_CONTRACT §1.3). The model
/// writes it after a refresh that reached the App Store (never `.readOnly(.unknown)`); the first
/// frame of the next launch shows `AccessCache.stateForLaunch` of what was kept, so an offline
/// launch keeps its rights.
protocol AccessCacheStore: Sendable {
    func load() -> AccessSnapshot?
    func save(_ snapshot: AccessSnapshot)
}

/// UserDefaults, self-contained (M5-34): the key lives here, not in `AppSettings`, so the Store
/// layer depends on the Access module only. The value is `Data` (`AccessCache.encode`); absent =
/// nothing was ever confirmed. `@unchecked`: `UserDefaults` is thread-safe but not marked Sendable.
struct UserDefaultsAccessCache: AccessCacheStore, @unchecked Sendable {
    static let defaultKey = "accessStateCache"

    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = UserDefaultsAccessCache.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// nil when nothing is kept or the data is not a snapshot.
    func load() -> AccessSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return AccessCache.decode(data)
    }

    func save(_ snapshot: AccessSnapshot) {
        defaults.set(AccessCache.encode(snapshot), forKey: key)
    }

    /// Forgets the kept state (`removeObject`). The model never calls this; the tests do.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Reads nothing, writes nothing: the screenshot mode and the tests.
struct NoopAccessCache: AccessCacheStore {
    func load() -> AccessSnapshot? { nil }
    func save(_ snapshot: AccessSnapshot) {}
}
