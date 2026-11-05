import Foundation
import CoreGraphics

/// The last cell of a page, open downward (1.1, M7A_CONTRACT D3 / §3.1 / §3.4 / §3.6; open to its full
/// length since 1.1.1, docs/R1_1_1.md): the month page's memo area (`.memo`) and the day page's free
/// memo area below 24:00 (`.extra`). One place for the height rule, so the layout engines and the
/// canvas's ledger (`InkLedger.needsMoreRoom`, 担当 P) read the same numbers. Pure functions; nothing
/// here is stored (K-5: the height is computed from the handwriting every time).
public enum PaperGrowth {
    /// The month's `.memo` or the day's `.extra`.
    public static func isTail(_ cell: CellKey) -> Bool {
        cell.isMemo || cell.isExtra
    }

    /// 1.1's steps, kept for the PDF (`exportTailHeight`): `700 + 400 × max(0, ceil((b − 300) / 400))`,
    /// at most `growMax` (6,000). b is cell-relative and already made finite and non-negative.
    static func stepped(_ b: CGFloat) -> CGFloat {
        let base = PaperSpec.memoMin - PaperSpec.growStep // 300
        let steps = Swift.max(0, ((b - base) / PaperSpec.growStep).rounded(.up))
        return Swift.min(PaperSpec.growMax, PaperSpec.memoMin + PaperSpec.growStep * steps)
    }

    /// 1.1.1: the last cell is open to its full length from the start (the owner's request,
    /// docs/R1_1_1.md): `max(growMax, b + 50)`, with b (the cell-relative bottom of the handwriting,
    /// `InkPage.inkBottoms()`) made finite and 0 or more (a non-finite or negative b counts as 0). Past
    /// 5,950 a line makes it taller (`b + 50`, so it stays visible, K-9): one from a 1.0 device or the web
    /// version, and on this device one written near the end of the cell (only its centre has to be
    /// inside, `drop`) or moved there with the lasso (`InkLedger.moveStrokes` does not go through `drop`,
    /// so each pull past the end adds up to 50 lu). Nothing is stored (K-5), and a line written here stays
    /// visible on a 1.0 device (`b + 50`) and on a 1.1 device (`exportTailHeight`'s steps).
    public static func tailHeight(inkBottom: CGFloat) -> CGFloat {
        let b = LayoutMath.sanitizedInk(inkBottom)
        return Swift.max(PaperSpec.growMax, b + PaperSpec.memoInkPad)
    }

    /// The height of the last cell on a PDF page (1.1's steps, so a PDF stays as long as its handwriting
    /// needs): 700, then 400 lu steps of blank paper below the handwriting, `max(stepped(b), b + 50)`.
    /// b ≤ 300 → 700, ≤ 700 → 1,100, ≤ 1,100 → 1,500, …, ≤ 5,500 → 5,900, then 6,000; never less than
    /// the 1.0 rule `b + 50`. The blank below b is at least 400 lu while b ≤ 5,600.
    public static func exportTailHeight(inkBottom: CGFloat) -> CGFloat {
        let b = LayoutMath.sanitizedInk(inkBottom)
        return Swift.max(stepped(b), b + PaperSpec.memoInkPad)
    }

    /// Does a stroke whose bottom is `inkBottom` (cell-relative) need a taller cell? The last cell:
    /// `tailHeight(b) > cellHeight + 0.001`. Any other cell: `b + 12 > cellHeight + 0.001` (the rule
    /// of the month and year rows, unchanged). The caller keeps its `growsWithInk` guard.
    public static func needsMoreRoom(cell: CellKey, cellHeight: CGFloat, inkBottom: CGFloat) -> Bool {
        if isTail(cell) {
            return tailHeight(inkBottom: inkBottom) > cellHeight + 0.001
        }
        return inkBottom + PaperSpec.inkPad > cellHeight + 0.001
    }

    /// Less than 400 lu of blank paper is left below a stroke whose bottom is b: b > growMax − growStep
    /// (5,600), so the cell (6,000 unless a deeper line made it taller) leaves less than one
    /// step of blank below it. The second trigger of 「メモ欄はここまでです」 (§3.4). false when b is not
    /// finite or negative.
    public static func reachesCap(inkBottom b: CGFloat) -> Bool {
        guard b.isFinite, b >= 0 else { return false }
        return b > PaperSpec.growMax - PaperSpec.growStep
    }

    /// Why a new stroke is dropped before it reaches the ledger (§3.4).
    public enum Drop: Equatable, Sendable {
        /// The centre of its paper bounds is outside the paper (M4C-25).
        case outsidePaper
        /// The centre is more than `growMax` below the top of the last cell (K-9).
        case beyondCap
    }

    /// The centre (paper coordinates) of a new stroke's bounds → why it is dropped, nil = keep it.
    /// `beyondCap` first: the page has a last cell, 0 ≤ x ≤ width and y > tail.minY + growMax (the
    /// paper ends there since 1.1.1, unless a line past 5,950 lu made it longer). Then
    /// `outsidePaper`: x < 0, x > width, y < 0 or y > height (the rule of M4C-25). A point that is not
    /// finite is `outsidePaper`.
    public static func drop(center: CGPoint, in layout: any PageLayout) -> Drop? {
        guard center.x.isFinite, center.y.isFinite else { return .outsidePaper }
        let size = layout.size
        if let tail = tail(of: layout), center.x >= 0, center.x <= size.width,
           center.y > tail.rect.minY + PaperSpec.growMax {
            return .beyondCap
        }
        if center.x < 0 || center.x > size.width || center.y < 0 || center.y > size.height {
            return .outsidePaper
        }
        return nil
    }

    /// The last cell of the page: the month's `.memo`, the day's `.extra` (when the layout has it);
    /// nil on the week and year pages.
    public static func tail(of layout: any PageLayout) -> (key: CellKey, rect: CGRect)? {
        let key: CellKey
        switch layout.kind {
        case .month: key = .memo
        case .day: key = .extra
        case .week, .year: return nil
        }
        guard let rect = layout.cells[key] else { return nil }
        return (key, rect)
    }

    /// True when only the height of the last cell changed between two layouts (§3.6), so the canvas
    /// may keep its drawing and update only its content size: same kind, pageId and paper width; the
    /// same set of cell keys; both have the same last cell; every other cell rect is `==`; the last
    /// cell keeps minX, minY and width and only its height differs; and `size.height − tail.height` is
    /// the same (the paper ends where the last cell ends). A month whose rows grew (the memo area moved
    /// down) is false; the week and year pages are always false.
    public static func onlyTailHeightChanged(old: any PageLayout, new: any PageLayout) -> Bool {
        guard old.kind == new.kind, old.pageId == new.pageId, old.size.width == new.size.width else { return false }
        guard let a = tail(of: old), let b = tail(of: new), a.key == b.key else { return false }
        let oldCells = old.cells
        let newCells = new.cells
        guard Set(oldCells.keys) == Set(newCells.keys) else { return false }
        for (key, rect) in oldCells where key != a.key {
            guard newCells[key] == rect else { return false }
        }
        guard a.rect.minX == b.rect.minX, a.rect.minY == b.rect.minY, a.rect.width == b.rect.width,
              a.rect.height != b.rect.height else { return false }
        return old.size.height - a.rect.height == new.size.height - b.rect.height
    }
}
