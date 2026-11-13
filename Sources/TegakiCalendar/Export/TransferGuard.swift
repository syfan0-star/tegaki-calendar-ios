import InkModel

/// 1.3 (docs/M7C_CONTRACT.md §3.11, §6.1, D14, D17): `SpanGuard.checkForTransfer` at the doors through which
/// handwriting leaves the app or comes into it — the PDF's page (`page:` of `PDFPageRenderer.render`, the
/// focus page's real `InkPage`), the data file (`ExportBuilder.exportJSON`, page by page) and the import
/// (`importable`, for the screen's `runImport`). The names that live only in a window's memory (the virtual
/// "span~…", the prefixed "<pageId>|…") must never pass them; the 1.2.3 pages and every page of the one-page
/// path have none, so for them nothing changes. A page of a kind a newer version makes still passes (F2:
/// only the window names are looked at, not the page id's form).
///
/// The strokes that come into a PDF from the neighbour pages (`SpanPDFInk`, D17) are no `InkPage` and are
/// not checked as one: `cleanNeighborInk` only leaves out one whose id or cell is a window name (what
/// `SpanComposer.neighborInk` never makes).
///
/// What is refused is reported through `onRefused` (the contract's 「記録し、Debug では止める」): Debug stops
/// (`assertionFailure`), Release goes on without the page. The tests replace it to watch.
enum TransferGuard {
    /// Called on the main actor with one line per refusal (the door and the page id). Default: stops a
    /// Debug build, nothing in Release.
    static var onRefused: (String) -> Void = { message in assertionFailure(message) }

    /// The door of the PDF: may `page` be drawn (`SpanGuard.checkForTransfer`)? A refused page is reported
    /// and gives no PDF (`PDFPageRenderer.render` returns empty data → `ExportError.renderFailed`).
    @MainActor
    static func allowsPDFPage(_ page: InkPage) -> Bool {
        guard SpanGuard.checkForTransfer(page) else {
            onRefused("TransferGuard: the PDF's page \(page.pageId) holds a window name")
            return false
        }
        return true
    }

    /// The neighbour strokes a PDF may draw: those whose id and cell are no window name
    /// (`SpanGuard.isWindowName`), in their order; each one left out is reported.
    @MainActor
    static func cleanNeighborInk(_ ink: [SpanPDFInk]) -> [SpanPDFInk] {
        ink.filter { item in
            guard SpanGuard.isWindowName(item.stroke.id) || SpanGuard.isWindowName(item.stroke.cell.raw) else { return true }
            onRefused("TransferGuard: a stroke of \(item.pageId) for the PDF carries a window name")
            return false
        }
    }

    /// The door of the import (§3.11: 前置名と span~ を断る): the outcome without the pages
    /// `SpanGuard.checkForTransfer` refuses, each counted as one more `skipped` (the import's sentence then
    /// says that pages were left out, as for a page it could not read) and reported. Nothing else changes, so
    /// a 1.2.3 file imports as before. For `CalendarRootScreen.runImport` (the screen's file), on the main
    /// actor after the parse.
    @MainActor
    static func importable(_ outcome: InkImport.Outcome) -> InkImport.Outcome {
        var kept: [InkPage] = []
        var refused = 0
        for page in outcome.pages {
            if SpanGuard.checkForTransfer(page) {
                kept.append(page)
            } else {
                refused += 1
                onRefused("TransferGuard: the import's page \(page.pageId) holds a window name")
            }
        }
        guard refused > 0 else { return outcome }
        return InkImport.Outcome(pages: kept, skipped: outcome.skipped + refused, pageCount: outcome.pageCount, isAppExport: outcome.isAppExport)
    }

    /// The door of the data file, for one page read from the store (`ExportBuilder.exportJSON`, off the main
    /// actor): true when it may be written. The caller reports a false one with `reportExportRefusal`.
    static func exportable(_ page: InkPage) -> Bool {
        SpanGuard.checkForTransfer(page)
    }

    /// Reports a page the data file left out (`exportable` false).
    @MainActor
    static func reportExportRefusal(_ pageId: String) {
        onRefused("TransferGuard: the data file left out \(pageId), which holds a window name")
    }
}
