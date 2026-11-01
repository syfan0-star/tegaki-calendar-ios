import Foundation
import CoreGraphics

/// The 1.0 app's rules for the handwriting of a page, written as pure functions of the frozen copy
/// (M7A_CONTRACT §1.4, K-7). The app's own code (PencilKit, the screen, the sync engine) cannot run in
/// this package, so each function transcribes the 1.0 lines named in the comment above it, with the
/// same conditions in the same order; ORIGIN.ranges holds the digest of every one of those ranges, so
/// CI notices when the ranges are wrong. Only public API of the copy is used (with the aliases of
/// tools/compat10 the same text runs against the real 1.0 InkModel). The real 1.0 app is checked as
/// well, on the simulator: tools/compat10/AppTests/Real10LedgerTests.swift.
public enum LedgerV10 {
    // a21e469 Sources/TegakiCalendar/Ink/InkLedger.swift:217-235
    // a21e469 Sources/TegakiCalendar/Ink/InkLedger.swift:285-290
    /// `InkLedger.drawing()`: the live strokes in `liveStrokes` order whose points are not empty and
    /// whose cell is in the layout (`cells[stroke.cell]`); a stroke of a cell the layout does not have
    /// stays in the page and is not drawn. The fingerprint map holds exactly these strokes, and an
    /// erase (`applyCanvasChange`: removedIds = the map's ids no longer on the canvas) can tombstone
    /// only them, so this is also the set the eraser and "erase everything on the canvas" reach.
    public static func drawnIds(page: InkPageV10, cells: Set<CellKeyV10>) -> [String] {
        var ids: [String] = []
        for stroke in page.liveStrokes {
            guard !stroke.points.isEmpty, cells.contains(stroke.cell) else { continue }
            ids.append(stroke.id)
        }
        return ids
    }

    // a21e469 Sources/TegakiCalendar/Ink/InkCanvasView.swift:1352-1367
    /// The lasso tests only the live strokes whose cell is in the layout (`cells[stroke.cell]`) and
    /// that have bounds; these are its candidates, whatever the polygon is.
    public static func lassoCandidates(page: InkPageV10, cells: Set<CellKeyV10>) -> [String] {
        var ids: [String] = []
        for stroke in page.liveStrokes {
            guard cells.contains(stroke.cell), stroke.paperBounds(cellOrigin: .zero) != nil else { continue }
            ids.append(stroke.id)
        }
        return ids
    }

    // a21e469 Sources/TegakiCalendar/Ink/InkCanvasView.swift:1120-1135
    // a21e469 Sources/TegakiCalendar/Ink/InkLedger.swift:408-411
    /// The finger's dots: `dotStrokeIds` looks at the live strokes and keeps those with
    /// `ledger.paperBounds(of:)` (live and in a cell of the layout) before its time, size and distance
    /// tests; these are its candidates.
    public static func dotCandidates(page: InkPageV10, cells: Set<CellKeyV10>) -> [String] {
        var ids: [String] = []
        for stroke in page.liveStrokes {
            guard page.strokes[stroke.id] != nil, page.deleted[stroke.id] == nil, cells.contains(stroke.cell),
                  stroke.paperBounds(cellOrigin: .zero) != nil else { continue }
            ids.append(stroke.id)
        }
        return ids
    }

    // a21e469 TegakiKit/Sources/Layout/PaperSpec.swift:23-25
    /// `PaperSpec.inkPad` and `PaperSpec.memoInkPad` of 1.0 (the copy of PaperSpec has only the week
    /// constants).
    public static let inkPad: CGFloat = 12
    public static let memoInkPad: CGFloat = 50

    // a21e469 Sources/TegakiCalendar/Ink/InkLedger.swift:321-325
    /// `InkLedger.needsMoreRoom`: the cell must grow when it grows with ink and the stroke's bottom
    /// plus the pad (50 in the memo area, 12 elsewhere) is below the cell's height. `cellHeight` nil
    /// = the layout has no such cell.
    public static func needsMoreRoom(_ stroke: InkStrokeV10, cellHeight: CGFloat?, growsWithInk: Bool) -> Bool {
        guard growsWithInk, let height = cellHeight else { return false }
        let pad = stroke.cell.isMemo ? memoInkPad : inkPad
        return stroke.bottom + pad > height
    }

    // a21e469 Sources/TegakiCalendar/Views/CalendarRootScreen.swift:805-810
    // a21e469 Sources/TegakiCalendar/Views/CalendarRootScreen.swift:1327-1333
    /// Opening a page (`show`) and reading it again (`reloadShownPage`): the loaded page is migrated,
    /// and it is saved (and sent) only when the migration changed it.
    public static func displayWouldSave(loaded: InkPageV10) -> Bool {
        let page = BandMigrationV10.migrate(loaded)
        return page != loaded
    }

    // a21e469 Sources/TegakiCalendar/Views/CalendarRootScreen.swift:878-889
    /// A remote update of the shown page (`applyRemote`): nil when the screen ignores it (another page,
    /// or nothing new); otherwise the page the screen keeps and whether it saves (and sends) it
    /// (there was something only this device had).
    public static func applyRemoteWouldSave(page: InkPageV10, updated: InkPageV10) -> (page: InkPageV10, saves: Bool)? {
        guard updated.pageId == page.pageId else { return nil }
        let merged = BandMigrationV10.migrate(InkPageV10.merge(page, updated))
        guard merged.contentDiffers(from: page) || merged.updatedAt != page.updatedAt else { return nil }
        return (merged, merged.contentDiffers(from: updated))
    }

    // a21e469 Sources/TegakiCalendar/Sync/SyncEngine.swift:633-647
    /// A fetched record (`mergeRemote`): the file is written when the merge differs from the local
    /// page, and the page is queued to be sent again when the merge differs from the remote one.
    public static func mergeRemoteOutcome(local: InkPageV10, remote: InkPageV10) -> (merged: InkPageV10, writesFile: Bool, marksDirty: Bool) {
        let merged = InkPageV10.merge(local, remote)
        return (merged, merged.contentDiffers(from: local), merged.contentDiffers(from: remote))
    }
}
