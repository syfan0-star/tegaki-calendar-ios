import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// The export sheet's words (M6_CONTRACT §3.2 / §3.6 / §7.2): the fixed titles and notes, the
/// progress line per kind, the finished line with the file name and size, the size text's three
/// ranges, the failure text of every `ExportError` (and of a foreign error), and which phase blocks
/// the swipe.
@MainActor
final class ExportSheetTests: XCTestCase {
    private let directory = URL(fileURLWithPath: "/tmp/TegakiCalendarExport", isDirectory: true)

    private func json(pages: Int, bytes: Int) -> ExportResult {
        let name = "てがきカレンダー 手書き 2026-10-17.json"
        return ExportResult(kind: .json, url: directory.appendingPathComponent(name), fileName: name, byteCount: bytes, pageCount: pages)
    }

    private func pdf(bytes: Int) -> ExportResult {
        let name = "てがきカレンダー 2026年10月 月.pdf"
        return ExportResult(kind: .pdf, url: directory.appendingPathComponent(name), fileName: name, byteCount: bytes, pageCount: 1)
    }

    func testTexts() {
        XCTAssertEqual(ExportSheet.title, "手書きを書き出す")
        XCTAssertEqual(ExportSheet.jsonTitle, "データファイル（JSON、すべてのページ）")
        XCTAssertEqual(ExportSheet.jsonNote, "この端末に保存されている手書きをすべて 1 つのファイルにまとめます。設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。")
        XCTAssertEqual(ExportSheet.pdfTitle, "このページを PDF")
        XCTAssertEqual(ExportSheet.pdfNote(pageTitle: "2026年10月", kind: .month), "いま開いているページ（2026年10月・月）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。")
        // The kind label is the file name's (`AppExport.kindLabel`): 週 / 日 / 年.
        XCTAssertEqual(ExportSheet.pdfNote(pageTitle: "2026年10月5日〜10月11日", kind: .week), "いま開いているページ（2026年10月5日〜10月11日・週）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。")
        XCTAssertTrue(ExportSheet.pdfNote(pageTitle: "2026年10月7日(水)", kind: .day).hasPrefix("いま開いているページ（2026年10月7日(水)・日）"))
        XCTAssertTrue(ExportSheet.pdfNote(pageTitle: "2026年", kind: .year).hasPrefix("いま開いているページ（2026年・年）"))
        for kind in PageKind.allCases {
            XCTAssertTrue(ExportSheet.pdfNote(pageTitle: "t", kind: kind).contains("・\(AppExport.kindLabel(kind))）"), "\(kind)")
        }
        // New words say 「この端末」, never 「この iPad」 (the sheet shows on an iPhone too, D2).
        XCTAssertFalse(ExportSheet.jsonNote.contains("iPad"))
        XCTAssertTrue(ExportSheet.jsonNote.contains("この端末"))

        XCTAssertEqual(ExportSheet.doneTitle, "書き出しました")
        XCTAssertEqual(ExportSheet.shareTitle, "共有…")
        XCTAssertEqual(ExportSheet.closeTitle, "閉じる")
        XCTAssertEqual(ExportSheet.nothingToExportText, "書き出す手書きがありません")
        XCTAssertEqual(ExportSheet.writeFailedText("容量不足"), "ファイルを書けませんでした: 容量不足")
        XCTAssertEqual(ExportSheet.renderFailedText, "PDF を作れませんでした")
    }

    func testProgressText() {
        XCTAssertEqual(ExportSheet.progressText(.building(.json, done: 3, total: 12)), "書き出しています… 3 / 12 ページ")
        XCTAssertEqual(ExportSheet.progressText(.building(.json, done: 0, total: 0)), "書き出しています… 0 / 0 ページ", "before the first report")
        XCTAssertEqual(ExportSheet.progressText(.building(.pdf, done: 0, total: 1)), "PDF を作っています…")
        XCTAssertEqual(ExportSheet.progressText(.choose), "")
        XCTAssertEqual(ExportSheet.progressText(.done(json(pages: 12, bytes: 1_258_291))), "")
        XCTAssertEqual(ExportSheet.progressText(.failed("x")), "")
    }

    func testDoneText() {
        XCTAssertEqual(ExportSheet.doneText(json(pages: 12, bytes: 1_258_291)), "てがきカレンダー 手書き 2026-10-17.json（12 ページ・1.2 MB）")
        XCTAssertEqual(ExportSheet.doneText(json(pages: 1, bytes: 512)), "てがきカレンダー 手書き 2026-10-17.json（1 ページ・512 B）")
        XCTAssertEqual(ExportSheet.doneText(pdf(bytes: 1_258_291)), "てがきカレンダー 2026年10月 月.pdf（1.2 MB）")
        XCTAssertEqual(ExportSheet.doneText(pdf(bytes: 524_288)), "てがきカレンダー 2026年10月 月.pdf（512 KB）", "the PDF has no page count")
    }

    func testByteText() {
        XCTAssertEqual(ExportSheet.byteText(512), "512 B")
        XCTAssertEqual(ExportSheet.byteText(524_288), "512 KB")
        XCTAssertEqual(ExportSheet.byteText(1_258_291), "1.2 MB")
        // The borders (1024-based): 1,023 B / 1 KB, 1,023 KB / 1.0 MB.
        XCTAssertEqual(ExportSheet.byteText(0), "0 B")
        XCTAssertEqual(ExportSheet.byteText(1_023), "1023 B")
        XCTAssertEqual(ExportSheet.byteText(1_024), "1 KB")
        XCTAssertEqual(ExportSheet.byteText(1_535), "1 KB", "whole kilobytes")
        XCTAssertEqual(ExportSheet.byteText(1_048_575), "1023 KB")
        XCTAssertEqual(ExportSheet.byteText(1_048_576), "1.0 MB")
        XCTAssertEqual(ExportSheet.byteText(23_598_869), "22.5 MB", "the large export of ExportBuilderTests")
        XCTAssertEqual(ExportSheet.byteText(1_073_741_824), "1024.0 MB", "no GB range")
    }

    func testFailureText() {
        XCTAssertEqual(ExportSheet.failureText(ExportError.nothingToExport), "書き出す手書きがありません")
        XCTAssertEqual(ExportSheet.failureText(ExportError.writeFailed("容量不足")), "ファイルを書けませんでした: 容量不足")
        XCTAssertEqual(ExportSheet.failureText(ExportError.renderFailed), "PDF を作れませんでした")
        XCTAssertNil(ExportSheet.failureText(ExportError.cancelled), "the sheet just closes; no toast")
        let foreign = NSError(domain: "ExportSheetTests", code: 7, userInfo: [NSLocalizedDescriptionKey: "ディスクが外れました"])
        XCTAssertEqual(ExportSheet.failureText(foreign), "書き出せませんでした: ディスクが外れました")
        XCTAssertEqual(ExportSheet.failureText(CancellationError()), "書き出せませんでした: \(CancellationError().localizedDescription)", "only ExportError.cancelled is silent")
    }

    func testIsInProgress() {
        XCTAssertFalse(ExportPhase.choose.isInProgress)
        XCTAssertTrue(ExportPhase.building(.json, done: 0, total: 0).isInProgress)
        XCTAssertTrue(ExportPhase.building(.json, done: 3, total: 12).isInProgress)
        XCTAssertTrue(ExportPhase.building(.pdf, done: 0, total: 1).isInProgress)
        XCTAssertFalse(ExportPhase.done(json(pages: 12, bytes: 1_258_291)).isInProgress)
        XCTAssertFalse(ExportPhase.failed("x").isInProgress)
        // Equatable (the owner's `onChange` and the tests compare phases).
        XCTAssertEqual(ExportPhase.building(.json, done: 3, total: 12), .building(.json, done: 3, total: 12))
        XCTAssertNotEqual(ExportPhase.building(.json, done: 3, total: 12), .building(.pdf, done: 3, total: 12))
        XCTAssertEqual(ExportPhase.done(pdf(bytes: 1)), .done(pdf(bytes: 1)))
    }
}
