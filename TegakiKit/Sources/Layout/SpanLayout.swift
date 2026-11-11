import Foundation
import CoreGraphics

/// What happens to a new stroke whose bounds' centre is at a point of the window
/// (docs/M7C_CONTRACT.md §2.1, §3.2, D15; `SpanLayout.drop(center:)`).
public enum SpanDrop: Equatable, Sendable {
    /// Keep it: `page` (a real page id) owns it, in its own cell `cell` (not prefixed; the window's
    /// name is `SpanName.prefixed(cell, page: page)`, what `inkCell(forCenter:)` gives).
    case keep(page: String, cell: CellKey)
    /// The centre is outside the band of pages (or outside its page's paper): dropped, as M4C-25 drops
    /// a stroke outside the paper today.
    case outsidePaper
    /// The centre is more than 6,000 lu below the top of its page's last cell (K-9,
    /// `PaperGrowth.Drop.beyondCap`, per page).
    case belowCap
    /// The centre is on a page that is only shown, not written (stage 1, 1.8; never in 1.3 unless the
    /// caller names such pages).
    case viewOnly
}

/// The window of joined pages as one layout (1.3, docs/M7C_CONTRACT.md §2.1, §3.2, §4.3; B_DESIGN.md
/// §2.4 2): the pages of `pages` side by side from x 0, page slot k at x = k × `plan.pageWidth`. It is a
/// `PageLayout`, so the canvas, the ledger and the lasso use it like a page:
/// - `pageId` is the virtual id "span~<kind>~<session>", the same however the window shifts.
/// - `cells` are every page's cells named "<pageId>|<cell>" (`SpanName`), moved right by the page's x.
/// - `inkCell(forCenter:)` picks the page owning the centre's x (half-open, a boundary goes right, D15),
///   then that page's own rule at the local point; past the band's ends the end pages' rules apply
///   (x == the band's right edge is the last page's x == 1400: its last column).
/// - `cell(at:)`, `hit`, `dayAt`, `eventRange`, `growsWithInk` go to the page under the point (or the
///   page a prefixed cell names) with the local point / the page's own name, so a prefixed name gets
///   the page's answer for the bare name; `snapRect` asks each page.
/// - `band(atY:)` and `bandTop` are the middle page's (the focus when the window is built around it;
///   the joined weeks and days share their rows).
/// A window of one page answers every question as that page does, with the cell names prefixed
/// (KitChecks fixes it, for the day the old path may be removed).
public struct SpanLayout: PageLayout {
    public let plan: SpanPlan
    /// The pages, left to right (slot 0 first).
    public let pages: [any PageLayout]
    /// The page number (`SpanPlan.index(of:)`) of slot 0.
    public let firstIndex: Int
    /// The floors the pages were laid out with (`SpanAlign`; the engines apply them, this keeps them so
    /// the next window starts from them).
    public let floors: SpanAlign.Floors
    /// The session number in the virtual page id.
    public let session: Int
    /// Page ids that are only shown (stage 1, 1.8): a new stroke there is `.viewOnly`. Empty in 1.3.
    public let viewOnly: Set<String>

    public let pageId: String
    public let size: CGSize
    public let cells: [CellKey: CGRect]
    public let dateLabels: [DateLabel]
    public let allDayBars: [AllDayBar]
    public let timedBoxes: [TimedEventBox]
    public let nowLine: NowLine?

    public init(pages: [any PageLayout], plan: SpanPlan, firstIndex: Int, floors: SpanAlign.Floors = .none, session: Int = 0, viewOnly: Set<String> = []) {
        self.plan = plan
        self.pages = pages
        self.firstIndex = firstIndex
        self.floors = floors
        self.session = session
        self.viewOnly = viewOnly
        pageId = SpanName.virtualPageId(plan.kind, session: session)
        let w = plan.pageWidth
        size = CGSize(width: CGFloat(pages.count) * w, height: pages.reduce(CGFloat(0)) { max($0, $1.size.height) })
        var cells: [CellKey: CGRect] = [:]
        var labels: [DateLabel] = []
        var bars: [AllDayBar] = []
        var boxes: [TimedEventBox] = []
        var now: NowLine?
        for (slot, page) in pages.enumerated() {
            let dx = CGFloat(slot) * w
            for (key, rect) in page.cells {
                cells[SpanName.prefixed(key, page: page.pageId)] = rect.offsetBy(dx: dx, dy: 0)
            }
            labels += page.dateLabels.map { var l = $0; l.frame = l.frame.offsetBy(dx: dx, dy: 0); return l }
            bars += page.allDayBars.map { var b = $0; b.frame = b.frame.offsetBy(dx: dx, dy: 0); return b }
            boxes += page.timedBoxes.map { var b = $0; b.frame = b.frame.offsetBy(dx: dx, dy: 0); return b }
            if now == nil, var line = page.nowLine {
                line.x0 += dx
                line.x1 += dx
                now = line
            }
        }
        self.cells = cells
        dateLabels = labels
        allDayBars = bars
        timedBoxes = boxes
        nowLine = now
    }

    public var kind: PageKind { plan.kind }

    // MARK: Pages and points

    /// The x (lu) of slot `slot`'s left edge.
    public func origin(ofSlot slot: Int) -> CGFloat {
        CGFloat(slot) * plan.pageWidth
    }

    /// The page number of slot `slot`.
    public func pageIndex(ofSlot slot: Int) -> Int {
        firstIndex + slot
    }

    /// The slot owning x (`SpanPlan.owner(ofCenterX:)`), kept on the band: left of it slot 0, right of it
    /// the last slot.
    public func slot(atX x: CGFloat) -> Int {
        min(max(0, plan.owner(ofCenterX: x)), max(0, pages.count - 1))
    }

    /// The point in slot `slot`'s own coordinates.
    public func localPoint(_ point: CGPoint, inSlot slot: Int) -> CGPoint {
        CGPoint(x: point.x - origin(ofSlot: slot), y: point.y)
    }

    /// The slot of the page a prefixed cell names; nil for a name that is not prefixed or names no
    /// page of the window.
    public func page(containing name: CellKey) -> Int? {
        guard let parts = SpanName.split(name.raw) else { return nil }
        return pages.firstIndex { $0.pageId == parts.page }
    }

    /// The slot holding a real page id; nil when the window has no such page.
    public func slot(ofPage pageId: String) -> Int? {
        pages.firstIndex { $0.pageId == pageId }
    }

    /// The page under a point and the point in its coordinates (§4.3, D23, stage 0): the page owning its
    /// x, kept on the band (a point left or right of the band goes to the end page, as a page's
    /// `eventRange` snaps a rect outside the paper to its nearest column). The event tool and "turn into
    /// an event" ask this, then that page's `eventRange` with the local rect, so an event made across a
    /// boundary belongs to the day of its centre's page. nil for a point that is not finite or an empty
    /// window. A window of one page gives (its page, the point itself).
    public func eventTarget(at point: CGPoint) -> (pageId: String, local: CGPoint)? {
        guard point.x.isFinite, point.y.isFinite, !pages.isEmpty else { return nil }
        let s = slot(atX: point.x)
        return (pages[s].pageId, localPoint(point, inSlot: s))
    }

    /// The middle page (the focus of a window built around it).
    private var middle: (any PageLayout)? {
        pages.isEmpty ? nil : pages[pages.count / 2]
    }

    // MARK: Ink

    /// What happens to a new stroke centred at `center` (§3.2, D15): outside the band (x < 0, x > the
    /// band's width, or not finite) `.outsidePaper`; on a view-only page `.viewOnly`; else the owner
    /// page's `PaperGrowth.drop` at the local point (`.beyondCap` → `.belowCap`, `.outsidePaper` → the
    /// same), and `.keep` with the owner and its own cell when that keeps it.
    public func drop(center: CGPoint) -> SpanDrop {
        guard center.x.isFinite, center.y.isFinite, !pages.isEmpty else { return .outsidePaper }
        guard center.x >= 0, center.x <= size.width else { return .outsidePaper }
        let s = slot(atX: center.x)
        let page = pages[s]
        if viewOnly.contains(page.pageId) { return .viewOnly }
        let local = localPoint(center, inSlot: s)
        switch PaperGrowth.drop(center: local, in: page) {
        case .beyondCap?: return .belowCap
        case .outsidePaper?: return .outsidePaper
        case nil: return .keep(page: page.pageId, cell: page.inkCell(forCenter: local))
        }
    }

    /// The owner page's cell for the local point, prefixed. Never nil (an empty window: `.grid`).
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        guard !pages.isEmpty else { return .grid }
        let s = slot(atX: point.x)
        return SpanName.prefixed(pages[s].inkCell(forCenter: localPoint(point, inSlot: s)), page: pages[s].pageId)
    }

    /// The cell under the point, prefixed; nil outside every page's paper.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite, !pages.isEmpty else { return nil }
        let s = slot(atX: point.x)
        return pages[s].cell(at: localPoint(point, inSlot: s)).map { SpanName.prefixed($0, page: pages[s].pageId) }
    }

    /// The named page's answer for its own name; false for a name that is not prefixed or names no
    /// page of the window.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        guard let parts = SpanName.split(cell.raw), let s = slot(ofPage: parts.page) else { return false }
        return pages[s].growsWithInk(CellKey(raw: parts.local))
    }

    /// True when the window holds the same pages in the same slots and every page either kept its
    /// geometry or changed only the height of its last cell (`PaperGrowth.onlyTailHeightChanged`), at
    /// least one of them (§3.3: the canvas's light path, per page). One page: that page's answer.
    public func onlyTailHeightChanged(from old: SpanLayout) -> Bool {
        guard old.kind == kind, old.pageId == pageId, old.firstIndex == firstIndex, old.pages.count == pages.count,
              old.size.width == size.width else { return false }
        var changed = false
        for (a, b) in zip(old.pages, pages) {
            guard a.pageId == b.pageId else { return false }
            if a.sameGeometry(as: b) { continue }
            guard PaperGrowth.onlyTailHeightChanged(old: a, new: b) else { return false }
            changed = true
        }
        return changed
    }

    // MARK: Taps and events

    /// The page under the point's answer at the local point.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite, !pages.isEmpty else { return nil }
        let s = slot(atX: point.x)
        return pages[s].hit(at: localPoint(point, inSlot: s))
    }

    /// The page under the point's answer at the local point (the week's day column; nil on the day).
    public func dayAt(point: CGPoint) -> DayKey? {
        guard point.x.isFinite, point.y.isFinite, !pages.isEmpty else { return nil }
        let s = slot(atX: point.x)
        return pages[s].dayAt(point: localPoint(point, inSlot: s))
    }

    /// The middle page's band (the joined pages share their rows).
    public func band(atY y: CGFloat) -> PageBand? {
        middle?.band(atY: y)
    }

    /// The middle page's band top.
    public func bandTop(_ band: PageBand) -> CGFloat? {
        middle?.bandTop(band)
    }

    /// The page under the rect's centre (`eventTarget`) and its answer for the local rect.
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect), let target = eventTarget(at: CGPoint(x: r.midX, y: r.midY)),
              let s = slot(ofPage: target.pageId) else { return nil }
        return pages[s].eventRange(for: r.offsetBy(dx: -origin(ofSlot: s), dy: 0), now: now, calendar: calendar)
    }

    /// The first page that shows the range, its rect moved to the window.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        for (slot, page) in pages.enumerated() {
            if let rect = page.snapRect(for: range, calendar: calendar) {
                return rect.offsetBy(dx: origin(ofSlot: slot), dy: 0)
            }
        }
        return nil
    }
}
