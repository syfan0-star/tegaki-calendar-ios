import Foundation
import InkModel
import Layout

/// 設定 › 情報 「いちばん線の多いページ」「今年の年のページ」 and the import check (1.1,
/// M7A_CONTRACT D5 / §5.2 / §5.3, K-9, 0-17): how many strokes the pages on this device hold.
///
/// - Everything is counted on this device and nothing is sent or stored (the footer says so).
/// - The files are read with `InkPageStore.peek(_:)`, which never moves a file to `.bak`, never
///   writes and never builds an `InkPage`, so the numbers are those of the files, before the read cap
///   (`InkPage.maxStrokes`): a page of 20,500 strokes is 20,500 here.
/// - The count of every page runs in the background (`Task.detached(priority: .utility)`) and stops
///   when the task that asked is cancelled (the settings sheet closes): `run` then returns nil.
/// - Screenshot mode uses `demo(year:)` (the four demo pages), never the store.
enum StrokeCensus {
    /// The two rows' values: the page with the most strokes (`StrokeBudget.largest`; nil when no page
    /// has a stroke), this year's year page (nil when it has no file) and the number of page files
    /// `peek` could not read.
    struct Result: Equatable, Sendable {
        var largest: StrokeBudget.Entry?
        var year: StrokeBudget.Entry?
        var unreadable: Int
    }

    // MARK: - Words (M7A_CONTRACT §6.2)

    /// Both rows while the pages are being counted.
    static let countingText = "数えています…"
    /// 「いちばん線の多いページ」 when no page has a stroke.
    static let noInkText = "まだ手書きがありません"
    /// After the value when the page has more than `StrokeBudget.legacyReadCap` (20,000) strokes: a
    /// 1.0 device keeps only 20,000 of them each time it reads the page (F8).
    static let legacyNote = "（古い版の端末では一部が表示されません）"

    /// 「いちばん線の多いページ」: 「数えています…」 while counting, 「まだ手書きがありません」 for nil,
    /// else 「月のページ（2026年10月）・3 本」 (plus `legacyNote` above 20,000 strokes).
    static func rowText(_ entry: StrokeBudget.Entry?, counting: Bool) -> String {
        if counting { return countingText }
        guard let entry = entry else { return noInkText }
        return entryText(entry)
    }

    /// 「今年の年のページ」: 「数えています…」 while counting, else 「年のページ（2026年）・12 本」, or
    /// 「年のページ（2026年）・0 本」 when the year page has no file (plus `legacyNote` above 20,000).
    static func yearRowText(_ entry: StrokeBudget.Entry?, year: Int, counting: Bool) -> String {
        if counting { return countingText }
        return entryText(entry ?? StrokeBudget.Entry(pageId: yearPageId(year), strokes: 0, tombstones: 0))
    }

    /// 「<page label>・<n> 本」, and `legacyNote` when n > 20,000.
    static func entryText(_ entry: StrokeBudget.Entry) -> String {
        let note = entry.strokes > StrokeBudget.legacyReadCap ? legacyNote : ""
        return StrokeBudget.pageLabel(entry.pageId) + "・" + StrokeBudget.countText(entry.strokes) + note
    }

    /// "y-2026".
    static func yearPageId(_ year: Int) -> String {
        PageNavigation.pageId(.year, focus: DayKey(year: year, month: 1, day: 1))
    }

    // MARK: - Counting

    /// Counts every page file of `store` in the background. nil when the calling task is cancelled
    /// (before, during or right after the count); `Task.detached` does not inherit the cancellation,
    /// so it is passed on by hand.
    static func run(store: InkPageStore, year: Int) async -> Result? {
        if Task.isCancelled { return nil }
        let task = Task.detached(priority: .utility) { () -> Result? in
            count(store: store, year: year, isCancelled: { Task.isCancelled })
        }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if Task.isCancelled { return nil }
        return result
    }

    /// The work of `run`, synchronous: `isCancelled` is asked before every page (nil as soon as it
    /// says yes). A page file `peek` cannot read is counted in `unreadable` and left alone.
    static func count(store: InkPageStore, year: Int, isCancelled: () -> Bool) -> Result? {
        var entries: [StrokeBudget.Entry] = []
        var unreadable = 0
        for pageId in store.allPageIds() {
            if isCancelled() { return nil }
            guard let peek = store.peek(pageId) else {
                unreadable += 1
                continue
            }
            entries.append(StrokeBudget.Entry(pageId: pageId, strokes: peek.strokeIds.count, tombstones: peek.tombstones))
        }
        if isCancelled() { return nil }
        return summary(entries, unreadable: unreadable, year: year)
    }

    /// Screenshot mode's values (§7.3): the four demo pages of the screenshot's focus (the 7th of
    /// October of `year` outside screenshot mode or for another year). With the demo strokes the
    /// largest is the day page (3 strokes, the same as the month page, whose pageId is larger), and
    /// this year's year page has 2 strokes.
    static func demo(year: Int) -> Result {
        let focus: DayKey
        if let shot = ScreenshotMode.current, shot.focus.year == year {
            focus = shot.focus
        } else {
            focus = ScreenshotMode.focusDay(for: YearMonth(year: year, month: 10))
        }
        let entries = PageKind.allCases.map { kind -> StrokeBudget.Entry in
            let page = ScreenshotMode.demoPage(kind: kind, focus: focus)
            return StrokeBudget.Entry(pageId: page.pageId, strokes: page.budgetCount, tombstones: page.deleted.count)
        }
        return summary(entries, unreadable: 0, year: year)
    }

    /// The result of counted pages, and the log line
    /// `budget: largest=<id> strokes=<n> tombstones=<m> pages=<k> unreadable=<u> year=<id>:<n> maxTombstones=<id>:<m>`
    /// (k = every page file looked at; "-" when there is no such page).
    static func summary(_ entries: [StrokeBudget.Entry], unreadable: Int, year: Int) -> Result {
        let yearId = yearPageId(year)
        let result = Result(largest: StrokeBudget.largest(entries), year: entries.first { $0.pageId == yearId }, unreadable: unreadable)
        NSLog("%@", logLine(result, entries: entries, yearId: yearId))
        return result
    }

    static func logLine(_ result: Result, entries: [StrokeBudget.Entry], yearId: String) -> String {
        var mostTombstones: StrokeBudget.Entry?
        for entry in entries where entry.tombstones > 0 {
            if let current = mostTombstones,
               entry.tombstones < current.tombstones || (entry.tombstones == current.tombstones && entry.pageId > current.pageId) {
                continue
            }
            mostTombstones = entry
        }
        let largest = result.largest
        return "budget: largest=\(largest?.pageId ?? "-") strokes=\(largest?.strokes ?? 0) tombstones=\(largest?.tombstones ?? 0)"
            + " pages=\(entries.count + result.unreadable) unreadable=\(result.unreadable)"
            + " year=\(yearId):\(result.year?.strokes ?? 0)"
            + " maxTombstones=\(mostTombstones?.pageId ?? "-"):\(mostTombstones?.tombstones ?? 0)"
    }

    // MARK: - The import check (§5.2)

    /// The page ids of `pages` (an import that was read) that would have more than 20,000 strokes on
    /// this device after the import (`StrokeBudget.importExceedsLegacyCap` with the ids `peek` finds in
    /// the device's file; a page without a file counts from nothing). In the order of `pages`, each id
    /// once. Off the main thread; nothing is written.
    static func pagesOverLegacyCap(_ pages: [InkPage], store: InkPageStore) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            overLegacyCap(pages, store: store)
        }.value
    }

    /// The work of `pagesOverLegacyCap`, synchronous.
    static func overLegacyCap(_ pages: [InkPage], store: InkPageStore) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for page in pages where !seen.contains(page.pageId) {
            let local = store.peek(page.pageId)?.strokeIds ?? []
            if StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: page) != nil {
                out.append(page.pageId)
                seen.insert(page.pageId)
            }
        }
        return out
    }
}
