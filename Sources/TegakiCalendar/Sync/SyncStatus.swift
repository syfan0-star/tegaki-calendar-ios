import Foundation

/// What the sync engine is doing right now (M4_CONTRACT §4.4, DESIGN §5.4). The header shows
/// `header`, the settings screen `settingsText` / `settingsFooter` (§6.1). The views only read these;
/// the engine is the only writer.
enum SyncStatus: Equatable, Sendable {
    /// iCloud is not used: the handwriting stays on this device (DESIGN §5.4 「この iPad のみ」; since 1.1
    /// 「この端末のみ」, M7A_CONTRACT §6.1).
    case localOnly(LocalOnlyReason)
    /// Nothing queued and the last round trip succeeded.
    case synced
    /// Something is queued (debouncing or waiting for a retry).
    case pending
    /// A round trip is running.
    case syncing
    /// `networkUnavailable`: sent once the connection is back.
    case offline
    /// Saving on the device goes on; iCloud is not reachable for a reason that needs the person.
    case error(SyncErrorKind)
    /// Another iCloud account is signed in; syncing stopped until the person answers (§6.4).
    case accountMismatch

    enum LocalOnlyReason: Equatable, Sendable {
        case noAccount, restricted, unknown, notAuthenticated
    }

    enum SyncErrorKind: Equatable, Sendable {
        case quota, permission, server(String)
    }
}

/// The engine's published state (`SyncEngine.snapshot`).
struct SyncSnapshot: Equatable, Sendable {
    var status: SyncStatus
    var lastSyncAt: Date?
    var dirtyCount: Int
    var webImportedAt: Date?
}

/// The ☁ in the page header (§6.1). `isError` is true for `.error` and `.accountMismatch`.
struct HeaderSync: Equatable, Sendable {
    var text: String
    var symbol: String
    var isError: Bool
}

/// The answer to 「別の iCloud アカウントです」 (§6.4).
enum AccountChangeChoice: Equatable {
    case keepInk, eraseInk, later
}

/// The result of 「Web 版の手書きを取り込む」 (§4.5 11). The memberwise init is
/// `ImportOutcome(pagesChanged:strokesAdded:pagesSeen:)` in this order.
struct ImportOutcome: Equatable, Sendable {
    var pagesChanged: Int
    var strokesAdded: Int
    var pagesSeen: Int
}

// MARK: - Wording (M4_CONTRACT §6.1; 1.1 says 「この端末」 for the device, M7A_CONTRACT §6.1)

extension SyncStatus {
    var header: HeaderSync {
        switch self {
        case .synced:
            return HeaderSync(text: "保存済み", symbol: "icloud", isError: false)
        case .pending:
            return HeaderSync(text: "同期中", symbol: "icloud", isError: false)
        case .syncing:
            return HeaderSync(text: "同期中", symbol: "arrow.triangle.2.circlepath.icloud", isError: false)
        case .offline:
            return HeaderSync(text: "オフライン", symbol: "icloud.slash", isError: false)
        case .localOnly:
            return HeaderSync(text: "この端末のみ", symbol: "icloud.slash", isError: false)
        case .error:
            return HeaderSync(text: "エラー", symbol: "exclamationmark.icloud", isError: true)
        case .accountMismatch:
            return HeaderSync(text: "停止中", symbol: "person.crop.circle.badge.exclamationmark", isError: true)
        }
    }

    /// The value next to 「iCloud 同期」 in the settings.
    var settingsText: String {
        switch self {
        case .synced:
            return "同期済み"
        case .pending, .syncing:
            return "同期中…"
        case .offline:
            return "オフライン"
        case .localOnly(.noAccount):
            return "iCloud にサインインしていません"
        case .localOnly(.restricted):
            return "この端末では iCloud が制限されています"
        case .localOnly(.unknown), .localOnly(.notAuthenticated):
            return "iCloud を確認できません"
        case .error(.quota):
            return "iCloud の容量が足りません"
        case .error(.permission):
            return "iCloud を使えません"
        case .error(.server):
            return "同期に失敗しました"
        case .accountMismatch:
            return "別の iCloud アカウントです"
        }
    }

    /// The footer of the 「同期」 section in the settings.
    var settingsFooter: String {
        switch self {
        case .synced:
            return "手書きはこの端末と、あなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きが見られます。"
        case .pending, .syncing:
            return "書いた手書きを iCloud へ送っています。"
        case .offline:
            return "オフラインです。手書きはこの端末に保存され、接続が戻ると同期されます。"
        case .localOnly(.noAccount):
            return "iCloud にサインインするとほかの端末と同期できます。手書きはこの端末の中だけに保存しています。"
        case .localOnly(.restricted):
            return "手書きはこの端末の中だけに保存しています。"
        case .localOnly(.unknown), .localOnly(.notAuthenticated):
            return "「設定」アプリで iCloud を確認してください。手書きはこの端末の中だけに保存しています。"
        case .error(.quota):
            return "iCloud の容量が不足しているため、手書きを同期できません。この端末には保存されています。"
        case .error(.permission):
            return "iCloud の設定でこのアプリの利用が許可されていません。"
        case .error(.server(let message)):
            return "手書きの同期に失敗しました。この端末には保存されています（あとで再試行します）。\n\(message)"
        case .accountMismatch:
            return "この端末の手書きは、前に同期していた iCloud アカウントのものです。「新しいアカウントで使い始める」から選んでください。"
        }
    }

    /// True for `.error(*)` and `.accountMismatch` (the header turns red).
    var isError: Bool {
        switch self {
        case .error, .accountMismatch:
            return true
        default:
            return false
        }
    }
}
