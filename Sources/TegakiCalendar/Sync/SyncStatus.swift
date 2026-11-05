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
            return HeaderSync(text: L.text("sync.header.saved"), symbol: "icloud", isError: false)
        case .pending:
            return HeaderSync(text: L.text("sync.header.syncing"), symbol: "icloud", isError: false)
        case .syncing:
            return HeaderSync(text: L.text("sync.header.syncing"), symbol: "arrow.triangle.2.circlepath.icloud", isError: false)
        case .offline:
            return HeaderSync(text: L.text("sync.header.offline"), symbol: "icloud.slash", isError: false)
        case .localOnly:
            return HeaderSync(text: L.text("sync.header.localOnly"), symbol: "icloud.slash", isError: false)
        case .error:
            return HeaderSync(text: L.text("sync.header.error"), symbol: "exclamationmark.icloud", isError: true)
        case .accountMismatch:
            return HeaderSync(text: L.text("sync.header.stopped"), symbol: "person.crop.circle.badge.exclamationmark", isError: true)
        }
    }

    /// The value next to 「iCloud 同期」 in the settings.
    var settingsText: String {
        switch self {
        case .synced:
            return L.text("sync.status.synced")
        case .pending, .syncing:
            return L.text("sync.status.syncing")
        case .offline:
            return L.text("sync.status.offline")
        case .localOnly(.noAccount):
            return L.text("sync.status.noAccount")
        case .localOnly(.restricted):
            return L.text("sync.status.restricted")
        case .localOnly(.unknown), .localOnly(.notAuthenticated):
            return L.text("sync.status.unknown")
        case .error(.quota):
            return L.text("sync.status.quota")
        case .error(.permission):
            return L.text("sync.status.permission")
        case .error(.server):
            return L.text("sync.status.serverError")
        case .accountMismatch:
            return L.text("sync.status.accountMismatch")
        }
    }

    /// The footer of the 「同期」 section in the settings.
    var settingsFooter: String {
        switch self {
        case .synced:
            return L.text("sync.footer.synced")
        case .pending, .syncing:
            return L.text("sync.footer.syncing")
        case .offline:
            return L.text("sync.footer.offline")
        case .localOnly(.noAccount):
            return L.text("sync.footer.noAccount")
        case .localOnly(.restricted):
            return L.text("sync.footer.restricted")
        case .localOnly(.unknown), .localOnly(.notAuthenticated):
            return L.text("sync.footer.unknown")
        case .error(.quota):
            return L.text("sync.footer.quota")
        case .error(.permission):
            return L.text("sync.footer.permission")
        case .error(.server(let message)):
            return L.format("sync.footer.serverError", message)
        case .accountMismatch:
            return L.text("sync.footer.accountMismatch")
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
