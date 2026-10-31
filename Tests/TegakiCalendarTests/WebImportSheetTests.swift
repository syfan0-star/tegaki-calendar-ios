import InkModel
import XCTest
@testable import TegakiCalendar

/// The import sheet's finished sentence per format (M6_CONTRACT §1.2 / §3.6 / §7.2, 0-12): the app's
/// own data file (a restore) says 「手書きを取り込みました（…）」, the web export keeps 「Web 版の手書きを
/// 取り込みました（…）」, nothing new reads the same for both, and the toast's second line is unchanged.
@MainActor
final class WebImportSheetTests: XCTestCase {
    private let imported = ImportOutcome(pagesChanged: 3, strokesAdded: 12, pagesSeen: 3)
    private let nothing = ImportOutcome(pagesChanged: 0, strokesAdded: 0, pagesSeen: 3)

    func testResultTextByFormat() {
        XCTAssertEqual(WebImportSheet.resultText(imported, isAppExport: true), "手書きを取り込みました（3 ページ・12 本）")
        XCTAssertEqual(WebImportSheet.resultText(imported, isAppExport: false), "Web 版の手書きを取り込みました（3 ページ・12 本）")
        XCTAssertEqual(WebImportSheet.resultText(imported), WebImportSheet.resultText(imported, isAppExport: false), "the default is the web form (the M4 callers)")
        XCTAssertEqual(WebImportSheet.resultText(nothing, isAppExport: true), "取り込むものはありませんでした（すべて取り込み済みです）")
        XCTAssertEqual(WebImportSheet.resultText(nothing, isAppExport: false), "取り込むものはありませんでした（すべて取り込み済みです）")

        // The toast: the result line, the skipped line under it as before.
        XCTAssertEqual(WebImportSheet.toastText(outcome: imported, skipped: 2, isAppExport: true), "手書きを取り込みました（3 ページ・12 本）\n2 ページは対象外のため飛ばしました")
        XCTAssertEqual(WebImportSheet.toastText(outcome: imported, skipped: 2, isAppExport: false), "Web 版の手書きを取り込みました（3 ページ・12 本）\n2 ページは対象外のため飛ばしました")
        XCTAssertEqual(WebImportSheet.toastText(outcome: imported, skipped: 0, isAppExport: true), "手書きを取り込みました（3 ページ・12 本）")
        XCTAssertEqual(WebImportSheet.toastText(outcome: nothing, skipped: 1, isAppExport: true), "取り込むものはありませんでした（すべて取り込み済みです）\n1 ページは対象外のため飛ばしました")
        XCTAssertEqual(WebImportSheet.toastText(outcome: imported, skipped: 0), WebImportSheet.toastText(outcome: imported, skipped: 0, isAppExport: false))
        XCTAssertEqual(WebImportSheet.skippedText(2), "2 ページは対象外のため飛ばしました")
        XCTAssertNil(WebImportSheet.skippedText(0))

        // The sheet's title does not change (M6-4); the two-format wording of `notAnExport` (§3.6).
        XCTAssertEqual(WebImportSheet.title, "Web 版の手書きを取り込む")
        XCTAssertEqual(WebImportSheet.notAnExportText, "このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません")
        XCTAssertEqual(WebImportSheet.invalidJSONText, "ファイルを読めませんでした")
        XCTAssertEqual(WebImportSheet.unsupportedVersionText(2), "このファイルは新しい形式です（v2）。アプリを更新してください")

        // `done` carries the format; it is not in progress whichever it is.
        XCTAssertFalse(WebImportPhase.done(imported, skipped: 0, isAppExport: true).isInProgress)
        XCTAssertFalse(WebImportPhase.done(imported, skipped: 0, isAppExport: false).isInProgress)
        XCTAssertNotEqual(WebImportPhase.done(imported, skipped: 0, isAppExport: true), .done(imported, skipped: 0, isAppExport: false))
        XCTAssertTrue(WebImportPhase.reading.isInProgress)
        XCTAssertTrue(WebImportPhase.importing(done: 1, total: 3).isInProgress)
    }

    /// 1.1 (M7A_CONTRACT §5.2 / §6.2): the question before an import that takes a page past 20,000
    /// strokes — the heading, the sentence with the page names joined by 「、」 (past four names, the
    /// first four and 「ほか n ページ」), the two buttons; the question can be swiped away (= 〔やめる〕).
    func testConfirmLargeTexts() {
        XCTAssertEqual(WebImportSheet.confirmLargeTitle, "線がとても多いページがあります")
        XCTAssertEqual(WebImportSheet.confirmLargeImportTitle, "取り込む")
        XCTAssertEqual(WebImportSheet.confirmLargeCancelTitle, "やめる")

        let lead = "取り込むと、線が 20,000 本を超えるページがあります（"
        let tail = "）。この版では全部表示されますが、古い版の端末ではその一部が表示されません。取り込みますか？"
        XCTAssertEqual(WebImportSheet.confirmLargeText(["月のページ（2026年10月）"]), lead + "月のページ（2026年10月）" + tail)
        XCTAssertEqual(WebImportSheet.confirmLargeText(["年のページ（2026年）", "日のページ（2026年10月7日）"]),
                       "取り込むと、線が 20,000 本を超えるページがあります（年のページ（2026年）、日のページ（2026年10月7日））。この版では全部表示されますが、古い版の端末ではその一部が表示されません。取り込みますか？")
        let four = ["A", "B", "C", "D"]
        XCTAssertEqual(WebImportSheet.confirmLargeList(four), "A、B、C、D", "four names are all listed")
        XCTAssertEqual(WebImportSheet.confirmLargeList(four + ["E"]), "A、B、C、D、ほか 1 ページ")
        XCTAssertEqual(WebImportSheet.confirmLargeList(four + ["E", "F", "G"]), "A、B、C、D、ほか 3 ページ")
        XCTAssertEqual(WebImportSheet.confirmLargeText(four + ["E", "F"]), lead + "A、B、C、D、ほか 2 ページ" + tail)
        XCTAssertEqual(WebImportSheet.confirmLargeListedPages, 4)

        // The labels come from the page ids (StrokeBudget.pageLabel).
        let labels = ["y-2026", "m1-2026-10", "w-2026-10-05", "d-2026-10-07", "m1-2026-11"].map(StrokeBudget.pageLabel)
        XCTAssertEqual(WebImportSheet.confirmLargeList(labels), "年のページ（2026年）、月のページ（2026年10月）、週のページ（2026年10月5日〜10月11日）、日のページ（2026年10月7日）、ほか 1 ページ")

        // The phase: not in progress (it can be swiped away), compared by its pages.
        XCTAssertFalse(WebImportPhase.confirmLarge(pages: ["A"]).isInProgress)
        XCTAssertEqual(WebImportPhase.confirmLarge(pages: ["A"]), .confirmLarge(pages: ["A"]))
        XCTAssertNotEqual(WebImportPhase.confirmLarge(pages: ["A"]), .confirmLarge(pages: ["B"]))
        XCTAssertNotEqual(WebImportPhase.confirmLarge(pages: []), .reading)
    }
}
