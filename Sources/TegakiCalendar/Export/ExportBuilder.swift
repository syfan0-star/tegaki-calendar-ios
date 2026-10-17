import Foundation
import InkModel
import Layout

/// The two exports of 設定 › データ › 「手書きを書き出す」 (M6_CONTRACT §2.2, D1): the data file
/// (`json`: every page of the device's handwriting as `tegaki-app-export` v1) and the PDF of the
/// page on the screen (`pdf`).
enum ExportKind: String, Equatable, Sendable {
    case json, pdf
}

/// A finished export: the file in `ExportBuilder.directory` (§1.5), ready for the share sheet.
struct ExportResult: Equatable, Sendable {
    var kind: ExportKind
    /// The written file.
    var url: URL
    /// `url.lastPathComponent`.
    var fileName: String
    /// Bytes written.
    var byteCount: Int
    /// JSON: the pages written. PDF: 1.
    var pageCount: Int
}

enum ExportError: Error, Equatable {
    /// JSON: no page is worth exporting (`AppExport.isWorthExporting`).
    case nothingToExport
    /// The file could not be created, written or closed (`localizedDescription` of the failure).
    case writeFailed(String)
    /// PDF: the renderer gave empty data.
    case renderFailed
    /// The task was cancelled (the sheet was closed).
    case cancelled
}

/// Builds the export files (M6_CONTRACT §2.2). One instance per export is fine: it holds no state
/// beyond its configuration. Every export starts by emptying `directory` (`cleanUp`, 0-14: the
/// previous export's file goes away here, never when the sheet closes, because the share sheet's
/// destination may still be reading it).
@MainActor
final class ExportBuilder {
    /// The page files (`SyncEngine.shared.store` in the app, a temporary store in the tests).
    let store: InkPageStore
    /// Where the files are written (`defaultDirectory()`: tmp/TegakiCalendarExport).
    let directory: URL
    let now: () -> Date
    /// Written into the JSON's `app` ("ios/1.0 (12)").
    let appText: String
    /// Decides the day in the JSON file name.
    let calendar: Calendar
    /// The offset of `exportedAt`.
    let timeZone: TimeZone

    init(store: InkPageStore,
         directory: URL = ExportBuilder.defaultDirectory(),
         now: @escaping () -> Date = Date.init,
         appText: String = ExportBuilder.appText,
         calendar: Calendar = DayKey.deviceCalendar,
         timeZone: TimeZone = .current) {
        self.store = store
        self.directory = directory
        self.now = now
        self.appText = appText
        self.calendar = calendar
        self.timeZone = timeZone
    }

    /// `tmp/TegakiCalendarExport` (§1.5): never Documents, so the Files app gets no 「このアプリ内」
    /// entry (`UISupportsDocumentBrowser` stays false), and the OS sweeps what is left behind.
    nonisolated static func defaultDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TegakiCalendarExport", isDirectory: true)
    }

    /// "ios/<CFBundleShortVersionString> (<CFBundleVersion>)" of `Bundle.main` (the same source as
    /// `SettingsScreen.versionText`); "ios/—" when the bundle has no version.
    nonisolated static var appText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        guard short != nil || build != nil else { return "ios/—" }
        return "ios/\(short ?? "—") (\(build ?? "—"))"
    }

    /// Removes everything inside `directory` (the directory itself stays; a missing directory is
    /// nothing to do). Failures are ignored.
    func cleanUp() {
        Self.emptyDirectory(directory)
    }

    nonisolated static func emptyDirectory(_ directory: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) else { return }
        for item in items {
            try? fm.removeItem(at: item)
        }
    }

    // MARK: - JSON (§1.1, §2.2)

    /// Every page of the store as one `tegaki-app-export` file: `cleanUp` → `store.allPageIds()`
    /// (sorted) → the file and `AppExport.header` → per id: load → `BandMigration.migrate` → when
    /// `isWorthExporting`, `pageText` (after `pageSeparator` from the second page on) → `progress(done,
    /// total)` on the main actor → `Task.checkCancellation` → `footer` → close. The reading, the
    /// migration and the formatting run in a detached task (`.userInitiated`) one page at a time
    /// inside an `autoreleasepool`: the file is never held whole in memory. Without a page worth
    /// writing the file is removed and `nothingToExport` is thrown; a cancelled task removes the
    /// partial file and throws `cancelled`; a file-system failure removes it and throws `writeFailed`.
    func exportJSON(progress: @escaping @MainActor (_ done: Int, _ total: Int) -> Void) async throws -> ExportResult {
        cleanUp()
        // Values only cross into the detached task: never `self` (a @MainActor class, §2.2).
        let store = self.store
        let directory = self.directory
        let appText = self.appText
        let exportedAtDate = now()
        let exportedAt = AppExport.exportedAtText(exportedAtDate, timeZone: timeZone)
        let fileName = AppExport.jsonFileName(exportedAt: exportedAtDate, calendar: calendar)
        let url = directory.appendingPathComponent(fileName, isDirectory: false)

        let worker = Task.detached(priority: .userInitiated) { () async throws -> (byteCount: Int, pageCount: Int) in
            let ids = store.allPageIds()
            let total = ids.count
            let writer = try ExportJSONWriter(directory: directory, url: url)
            do {
                try writer.write(AppExport.header(exportedAt: exportedAt, app: appText))
                for (index, id) in ids.enumerated() {
                    try autoreleasepool {
                        let page = BandMigration.migrate(store.load(id))
                        guard AppExport.isWorthExporting(page) else { return }
                        if writer.pageCount > 0 {
                            try writer.write(AppExport.pageSeparator)
                        }
                        try writer.write(AppExport.pageText(page))
                        writer.pageCount += 1
                    }
                    await progress(index + 1, total)
                    try Task.checkCancellation()
                }
                guard writer.pageCount > 0 else { throw ExportError.nothingToExport }
                try writer.write(AppExport.footer)
                try writer.close()
                return (writer.byteCount, writer.pageCount)
            } catch {
                writer.abandon()
                throw error
            }
        }
        // The detached task does not inherit cancellation: forward it (the sheet closed, §2.2).
        let outcome = await withTaskCancellationHandler {
            await worker.result
        } onCancel: {
            worker.cancel()
        }
        if Task.isCancelled {
            try? FileManager.default.removeItem(at: url)
            throw ExportError.cancelled
        }
        switch outcome {
        case .success(let written):
            return ExportResult(kind: .json, url: url, fileName: fileName, byteCount: written.byteCount, pageCount: written.pageCount)
        case .failure(let error):
            throw Self.exportError(error)
        }
    }

    /// `ExportError` as it is; `CancellationError` → `.cancelled`; anything else → `.writeFailed`.
    nonisolated static func exportError(_ error: Error) -> ExportError {
        if let exportError = error as? ExportError { return exportError }
        if error is CancellationError { return .cancelled }
        return .writeFailed(error.localizedDescription)
    }

    // MARK: - PDF (§1.4, §2.2)

    /// The page on the screen as a one-page PDF: `cleanUp` → `PDFPageRenderer.render` (titled
    /// `PageNavigation.title(kind, focus:)`) → empty data is `renderFailed` → `Data.write(.atomic)`.
    /// Synchronous on the main actor (the paper renderers and PencilKit's picture are main-actor
    /// work, about a second; the caller lets SwiftUI draw its spinner first, §3.3). The page is
    /// `BandMigration.migrate`d on the way in (idempotent; the ledger has done it already).
    func exportPDF(paper: PaperContent, page: InkPage, kind: PageKind, focus: DayKey) throws -> ExportResult {
        cleanUp()
        let title = PageNavigation.title(kind, focus: focus)
        let data = PDFPageRenderer.render(paper, page: BandMigration.migrate(page), title: title)
        guard !data.isEmpty else { throw ExportError.renderFailed }
        let fileName = AppExport.pdfFileName(kind: kind, focus: focus)
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        return ExportResult(kind: .pdf, url: url, fileName: fileName, byteCount: data.count, pageCount: 1)
    }
}

/// The streamed JSON file of `exportJSON`: `FileManager.createFile` → `FileHandle(forWritingTo:)`
/// → `write` pieces of text → `close`. Every failure is `ExportError.writeFailed` with the
/// underlying description; `abandon` closes and removes a partial file.
private final class ExportJSONWriter {
    let url: URL
    private var handle: FileHandle?
    private(set) var byteCount = 0
    var pageCount = 0

    init(directory: URL, url: URL) throws {
        self.url = url
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        guard fm.createFile(atPath: url.path, contents: nil) else {
            throw ExportError.writeFailed("ファイルを作成できません: \(url.lastPathComponent)")
        }
        do {
            handle = try FileHandle(forWritingTo: url)
        } catch {
            try? fm.removeItem(at: url)
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }

    func write(_ text: String) throws {
        guard let handle = handle else { throw ExportError.writeFailed("ファイルは閉じられています") }
        let data = Data(text.utf8)
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        byteCount += data.count
    }

    func close() throws {
        guard let handle = handle else { return }
        self.handle = nil
        do {
            try handle.close()
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }

    /// Closes (ignoring failures) and removes the file.
    func abandon() {
        if let handle = handle {
            self.handle = nil
            try? handle.close()
        }
        try? FileManager.default.removeItem(at: url)
    }
}
