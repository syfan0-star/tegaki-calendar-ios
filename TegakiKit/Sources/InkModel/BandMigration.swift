import Foundation
import CoreGraphics

/// Moves the handwriting of the week / day pages' former all-day band onto the time grid
/// (M4B_CONTRACT §3.1). From M3a to M4 the band was part of the paper, with its own ink cells
/// ("allday:YYYY-MM-DD" on the week page, "allday" on the day page). Since M4b the band is a fixed
/// view outside the paper and the paper starts at 0:00, so every device moves those strokes to the
/// `grid` cell when it loads a page: the x shifts by the column's origin, the y stays (the band's
/// top was the paper's top, so the shape is kept exactly, M4B-26), the id stays (the existing merge
/// rule `InkPage.compareStrokes` lets "grid" beat "allday…", so iCloud converges, §3.2). Idempotent;
/// both key forms stay readable forever. Pure functions: the ledger (担当 P) and the screen (担当 U)
/// call the same `migrate`.
public enum BandMigration {
    private static let weekBandPrefix = "allday:"

    /// "allday" or a key starting with "allday:".
    public static func isBandCell(_ cell: CellKey) -> Bool {
        cell.isAllDayDay || cell.raw.hasPrefix(weekBandPrefix)
    }

    /// The stroke moved onto the grid, or nil when it is not a band stroke of a week / day page
    /// (it is then used as it is).
    /// - Week page "w-YYYY-MM-DD" (the Monday): col = clamp(the key's day − Monday, 0, 6), the
    ///   x of every point += 64 + col × 190.857… (the band cell's origin was (64 + col × colW, 0),
    ///   the grid's is (0, 0)); y unchanged. A key whose date cannot be read is column 0; a page id
    ///   whose date is not a Monday is taken as the Monday (`PageNavigation.pageId` never makes one).
    /// - Day page "d-YYYY-MM-DD": the cell only (both origins are (0, 0)).
    /// - Other pages (m1- / y-) and other cells: nil.
    /// id, t, dev, tool, color and the number of points are kept; the points are rebuilt in place
    /// (`InkStroke.translated` would make a new id).
    public static func migrated(_ stroke: InkStroke, pageId: String) -> InkStroke? {
        guard isBandCell(stroke.cell) else { return nil }
        let dx: CGFloat
        if pageId.hasPrefix("w-") {
            var col = 0
            if let monday = DayKey(ymd: String(pageId.dropFirst(2))), let date = stroke.cell.allDayDate {
                col = min(max(date.dayNumber - monday.dayNumber, 0), PaperSpec.weekColumns - 1)
            }
            dx = PaperSpec.weekGutter + CGFloat(col) * PaperSpec.weekColumnWidth
        } else if pageId.hasPrefix("d-") {
            dx = 0
        } else {
            return nil
        }
        let points = stroke.points.map { p in
            InkPoint(
                x: p.x + dx, y: p.y, dtMs: p.dtMs,
                sizeW: p.sizeW, sizeH: p.sizeH, opacity: p.opacity, force: p.force,
                azimuth: p.azimuth, altitude: p.altitude
            )
        }
        return InkStroke(id: stroke.id, cell: .grid, tool: stroke.tool, color: stroke.color, t: stroke.t, dev: stroke.dev, points: points)
    }

    /// True when a live stroke of the page would be moved by `migrate`.
    public static func needsMigration(_ page: InkPage) -> Bool {
        page.strokes.values.contains { page.deleted[$0.id] == nil && migrated($0, pageId: page.pageId) != nil }
    }

    /// The page with its band strokes moved onto the grid; the page itself (`==`) when there is
    /// nothing to move. `updatedAt`, the tombstones and the unknown items are untouched; strokes of
    /// an unknown tool (`unknownStrokes`) are not read. Idempotent: migrate(migrate(p)) == migrate(p).
    public static func migrate(_ page: InkPage) -> InkPage {
        var out = page
        var changed = false
        for (id, stroke) in page.strokes where page.deleted[id] == nil {
            if let moved = migrated(stroke, pageId: page.pageId) {
                out.strokes[id] = moved
                changed = true
            }
        }
        return changed ? out : page
    }
}
