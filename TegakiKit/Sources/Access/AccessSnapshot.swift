// The cached state (M5_CONTRACT §1.3): the last state StoreKit confirmed, kept in UserDefaults by the
// Store layer so an offline launch keeps its rights. The first frame shows `stateForLaunch`.
import Foundation

public struct AccessSnapshot: Equatable, Codable, Sendable {
    public var state: AccessState
    public var savedAt: Date

    public init(state: AccessState, savedAt: Date) {
        self.state = state
        self.savedAt = savedAt
    }
}

public enum AccessCache {
    /// JSONEncoder、日付は .iso8601（秒まで。1 秒未満は落ちる）
    public static func encode(_ snapshot: AccessSnapshot) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(snapshot)) ?? Data()
    }

    /// 壊れていれば nil
    public static func decode(_ data: Data) -> AccessSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AccessSnapshot.self, from: data)
    }

    /// 起動の最初の 1 フレーム用: 控えの期限を now で切り直す。
    /// nil → `.readOnly(.unknown)`; 期限内 → そのまま; 自動更新が予定されていた（`willAutoRenew: true`、
    /// `inGrace` でない）控えは `until` から `offlineRenewalAllowanceDays` の間はそのまま（Apple 側では
    /// 更新済みのはず。M5-30）; `inGrace` で期限切れ → `.readOnly(.billingRetry)`; それ以外の期限切れ →
    /// `.readOnly(.expired)`; `.readOnly(r)` → そのまま。
    public static func stateForLaunch(cached: AccessSnapshot?, now: Date) -> AccessState {
        guard let cached else { return .readOnly(.unknown) }
        switch cached.state {
        case .subscribed(let s):
            if s.until > now { return cached.state }
            if s.inGrace { return .readOnly(.billingRetry) }
            if s.willAutoRenew, now < allowanceEnd(s.until) { return cached.state }
            return .readOnly(.expired)
        case .trial(let t):
            if t.until > now { return cached.state }
            if t.willAutoRenew, now < allowanceEnd(t.until) { return cached.state }
            return .readOnly(.expired)
        case .readOnly:
            return cached.state
        }
    }

    /// 自動更新が予定されていた控えは、回線が無いまま更新日をまたいでもこの日数は書ける（M5-30）
    public static let offlineRenewalAllowanceDays = 3

    private static func allowanceEnd(_ until: Date) -> Date {
        until.addingTimeInterval(TimeInterval(offlineRenewalAllowanceDays) * 86_400)
    }
}
