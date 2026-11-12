#if SPAN_PROTOTYPE
import CoreGraphics
import Foundation
import Layout
import QuartzCore
import UIKit

// The prototype's week memo (1.3, docs/M7C_CONTRACT.md §4.5, §4.6, §5.1, §5.2; PLAN_WEEK_MEMO.md): the free
// memo below 24:00 of the week page, a sample before the week memo's own stage (§5: `WeekLayoutEngine`,
// `PaperGrowth`, `ZoomPolicy` and `WeekPaper` stay as they are until then). It is the cell `extra` of the
// week's page (K-1's safe name, the day's free memo's), 6,000 lu tall like the day's, lined up across the
// window (`SpanAlign`, D16), its strokes saved in the prototype's own "proto-" pages only. Its lines are drawn
// by layers under the canvas, in one of the forms the sample images compare (§4.5): ruled lines only
// (the default, the day's free memo's look), a square grid, or the second form of PLAN_WEEK_MEMO.md's Q2 (the
// weekday dividers and today's and the weekend's tints running on down). Compiled only into the prototype build
// (`SPAN_PROTOTYPE`); it goes away with the prototype (S6).

/// The forms of the week memo the sample images put side by side (§4.5; §0.6: ruled lines only is the
/// default).
enum SpanPrototypeMemoStyle: String, CaseIterable, Sendable {
    /// Ruled lines every 50 lu, as the day's free memo (`DayPaper.drawExtra`): PLAN_WEEK_MEMO.md Q2's first form
    /// (today's and the weekend's colours and the gutter's line stop at 24:00).
    case ruled
    /// The same ruled lines and vertical lines every 50 lu: a square grid (§4.5's second form as written; the day's
    /// free memo has ruled lines only, so this one is the prototype's reading of it).
    case grid
    /// PLAN_WEEK_MEMO.md Q2's second form (review B3): the ruled lines, with the gutter's line and the column lines of
    /// the week running on down and today's and the weekend's (and a holiday's) columns tinted lightly (the paper's
    /// soft tints), so the memo is read day by day.
    case weekdays
}

/// What the `weekdays` form draws of a week page's columns in its memo (page-relative lu): the gutter's line, the
/// lines between the 7 columns, and the columns tinted (today over a weekend or a holiday, as the week's paper).
struct SpanPrototypeMemoColumns: Equatable {
    struct Tint: Equatable {
        var x: CGFloat
        var width: CGFloat
        var today: Bool
    }

    var gutter: CGFloat
    var lines: [CGFloat]
    var tints: [Tint]

    /// The columns of `week` (`WeekPaper`'s rule: today's tint over the weekend's / a holiday's).
    init(week: WeekPageLayout) {
        gutter = PaperSpec.weekGutter
        lines = (1..<PaperSpec.weekColumns).map { PaperSpec.weekGutter + CGFloat($0) * PaperSpec.weekColumnWidth }
        var tints: [Tint] = []
        for (column, label) in week.dateLabels.enumerated() {
            let today = week.todayColumn == column
            guard today || label.tone != .normal else { continue }
            let frame = week.columnFrame(column)
            tints.append(Tint(x: frame.minX, width: frame.width, today: today))
        }
        self.tints = tints
    }
}

/// One week page with the free memo below 24:00 (§5.2): the week as 1.2.3 lays it out (`week`, 1400 × 1920,
/// what the paper draws and 「1 ページずつ」 shows) and the cell `extra` under it, x 0…1400, y 1920…1920 +
/// height. Above 24:00 every answer is the week's; in the memo a stroke belongs to `extra`, which grows with
/// ink, and taps, days, bands and events say what the day's free memo says (no event is made there).
struct SpanPrototypeWeekMemoLayout: PageLayout {
    let week: WeekPageLayout
    /// The memo's rect (lu).
    let memo: CGRect
    let size: CGSize
    let cells: [CellKey: CGRect]

    /// `memoHeight` is at least `PaperGrowth.tailHeight` of an empty memo (6,000 lu): the caller passes the
    /// window's floor (`SpanAlign`).
    init(week: WeekPageLayout, memoHeight: CGFloat) {
        self.week = week
        let top = week.size.height
        let height = max(PaperSpec.growMax, memoHeight.isFinite ? memoHeight : 0)
        memo = CGRect(x: 0, y: top, width: week.size.width, height: height)
        size = CGSize(width: week.size.width, height: top + height)
        var cells = week.cells
        cells[.extra] = memo
        self.cells = cells
    }

    var kind: PageKind { .week }
    var pageId: String { week.pageId }
    var dateLabels: [DateLabel] { week.dateLabels }
    var allDayBars: [AllDayBar] { week.allDayBars }
    var timedBoxes: [TimedEventBox] { week.timedBoxes }
    var nowLine: NowLine? { week.nowLine }

    /// The week's columns as the `weekdays` form draws them in the memo.
    var columns: SpanPrototypeMemoColumns {
        SpanPrototypeMemoColumns(week: week)
    }

    /// Below 24:00 (a point that is finite).
    private func inMemo(_ point: CGPoint) -> Bool {
        point.y.isFinite && point.y >= memo.minY
    }

    func cell(at point: CGPoint) -> CellKey? {
        guard inMemo(point) else { return week.cell(at: point) }
        guard point.x.isFinite, point.x >= 0, point.x <= size.width, point.y < size.height else { return nil }
        return .extra
    }

    /// A centre below 24:00 is the memo's (beside or below the paper too, as the day's last cell takes them);
    /// above, the week's rule.
    func inkCell(forCenter point: CGPoint) -> CellKey {
        inMemo(point) ? .extra : week.inkCell(forCenter: point)
    }

    func growsWithInk(_ cell: CellKey) -> Bool {
        cell.isExtra || week.growsWithInk(cell)
    }

    func hit(at point: CGPoint) -> HitTarget? {
        inMemo(point) ? nil : week.hit(at: point)
    }

    func dayAt(point: CGPoint) -> DayKey? {
        inMemo(point) ? nil : week.dayAt(point: point)
    }

    func band(atY y: CGFloat) -> PageBand? {
        guard y.isFinite, y >= memo.minY else { return week.band(atY: y) }
        return y < size.height ? .extra : nil
    }

    func bandTop(_ band: PageBand) -> CGFloat? {
        band == .extra ? memo.minY : week.bandTop(band)
    }

    /// No event is made in the memo (§5.2, as in the day's free memo): a rect centred there is nil.
    func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard rect.midY.isFinite, rect.midY < memo.minY else { return nil }
        return week.eventRange(for: rect, now: now, calendar: calendar)
    }

    func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        week.snapRect(for: range, calendar: calendar)
    }
}

/// The memo's lines of every page of the window, under the canvas and above the paper: for each page a
/// strong line at 24:00 (the day's free memo's), ruled lines every 50 lu inset 20 lu, with 「方眼」 vertical
/// lines every 50 lu too, with the `weekdays` form the week's column lines and tints running on down, and the
/// heading 「自由メモ」. Plain colour layers (no drawing of their own, so no
/// backing store), placed in content points: a scroll moves the whole (`bounds.origin`), a zoom or another
/// window places them again.
@MainActor
final class SpanPrototypeMemoView: UIView {
    /// What the layers were placed for.
    private struct Placement: Equatable {
        var rects: [CGRect]
        var columns: [SpanPrototypeMemoColumns?]
        var zoom: CGFloat
        var style: SpanPrototypeMemoStyle
        var scale: CGFloat
    }

    /// The layers of one page's memo.
    private final class PageLayers {
        let root = CALayer()
        let top = CALayer()
        let rules = CAReplicatorLayer()
        let rule = CALayer()
        let columns = CAReplicatorLayer()
        let column = CALayer()
        let label = CATextLayer()
        /// The `weekdays` form: the column tints under everything, the column lines and the gutter's line above the
        /// ruled lines.
        let tints = CALayer()
        let dividers = CALayer()

        init() {
            rules.addSublayer(rule)
            columns.addSublayer(column)
            for layer in [tints, rules, columns, dividers, top, label] as [CALayer] {
                root.addSublayer(layer)
            }
            top.backgroundColor = PaperPalette.lineStrong.cgColor
            rule.backgroundColor = PaperPalette.rule.cgColor
            column.backgroundColor = PaperPalette.rule.cgColor
        }
    }

    private var pages: [PageLayers] = []
    private var placed: Placement?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The memo of each page (`rects`, band lu; an empty rect for a page without one, `columns` its week's columns)
    /// at `zoom`, the content offset `offset` at the view's top-left, in `style`.
    func show(rects: [CGRect], columns: [SpanPrototypeMemoColumns?] = [], zoom: CGFloat, offset: CGPoint, style: SpanPrototypeMemoStyle) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let origin = CGPoint(x: offset.x.isFinite ? offset.x : 0, y: offset.y.isFinite ? offset.y : 0)
        if bounds.origin != origin {
            bounds.origin = origin
        }
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2
        let placement = Placement(rects: rects, columns: columns, zoom: zoom, style: style, scale: scale)
        guard placement != placed, zoom.isFinite, zoom > 0 else { return }
        placed = placement
        while pages.count < rects.count {
            let page = PageLayers()
            layer.addSublayer(page.root)
            pages.append(page)
        }
        while pages.count > rects.count {
            pages.removeLast().root.removeFromSuperlayer()
        }
        for (index, (page, rect)) in zip(pages, rects).enumerated() {
            place(page, rect: rect, columns: index < columns.count ? columns[index] : nil, zoom: zoom, style: style, scale: scale)
        }
    }

    /// One page's layers for its memo `rect` (lu) at `zoom` (content points = lu × zoom).
    private func place(_ page: PageLayers, rect: CGRect, columns weekColumns: SpanPrototypeMemoColumns?, zoom: CGFloat,
                       style: SpanPrototypeMemoStyle, scale: CGFloat) {
        guard !rect.isEmpty, rect.width.isFinite, rect.height.isFinite else {
            page.root.isHidden = true
            return
        }
        page.root.isHidden = false
        let step = PaperSpec.dayRuleStep
        let inset = PaperSpec.dayRuleInset
        let line: CGFloat = 1 // pt: `PaperText.hairline` at any zoom
        page.root.frame = CGRect(x: rect.minX * zoom, y: rect.minY * zoom, width: rect.width * zoom, height: rect.height * zoom)
        page.top.frame = CGRect(x: 0, y: -line / 2, width: rect.width * zoom, height: line)

        let ruleCount = max(0, Int((rect.height / step).rounded(.up)) - 1)
        page.rules.frame = page.root.bounds
        page.rules.instanceCount = ruleCount
        page.rules.instanceTransform = CATransform3DMakeTranslation(0, step * zoom, 0)
        page.rule.frame = CGRect(x: inset * zoom, y: step * zoom - line / 2, width: (rect.width - 2 * inset) * zoom, height: line)

        placeWeekdays(page, rect: rect, columns: style == .weekdays ? weekColumns : nil, zoom: zoom, line: line)

        page.columns.isHidden = style != .grid
        let columnCount = max(0, Int(((rect.width - 2 * inset) / step).rounded(.down)) + 1)
        page.columns.frame = page.root.bounds
        page.columns.instanceCount = columnCount
        page.columns.instanceTransform = CATransform3DMakeTranslation(step * zoom, 0, 0)
        page.column.frame = CGRect(x: inset * zoom - line / 2, y: 0, width: line, height: rect.height * zoom)

        // The heading as the day's free memo writes it (`DayPaper.drawExtra`): 14 lu, at least 10.5 pt.
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: ZoomPolicy.readableZoom(.week)) * zoom
        let font = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let text = NSAttributedString(string: L.text("paper.freeMemo"), attributes: [
            .font: font,
            .foregroundColor: PaperPalette.memoLabel,
            .kern: labelSize * 0.15,
        ])
        let textSize = text.size()
        page.label.string = text
        page.label.contentsScale = scale
        page.label.frame = CGRect(x: inset * zoom, y: 6 * zoom, width: ceil(textSize.width) + 4, height: ceil(textSize.height) + 2)
    }

    /// The `weekdays` form (`columns` nil: hidden): a plain layer per tint (the paper's soft tints) and per line (the
    /// gutter's strong, the columns' plain), the whole height of the memo.
    private func placeWeekdays(_ page: PageLayers, rect: CGRect, columns: SpanPrototypeMemoColumns?, zoom: CGFloat, line: CGFloat) {
        guard let columns else {
            page.tints.isHidden = true
            page.dividers.isHidden = true
            return
        }
        page.tints.isHidden = false
        page.dividers.isHidden = false
        page.tints.frame = page.root.bounds
        page.dividers.frame = page.root.bounds
        let height = rect.height * zoom
        let tintLayers = Self.layers(of: page.tints, count: columns.tints.count)
        for (layer, tint) in zip(tintLayers, columns.tints) {
            layer.backgroundColor = (tint.today ? PaperPalette.todayTintSoft : PaperPalette.weekendTintSoft).cgColor
            layer.frame = CGRect(x: tint.x * zoom, y: 0, width: tint.width * zoom, height: height)
        }
        let lineLayers = Self.layers(of: page.dividers, count: columns.lines.count + 1)
        for (index, layer) in lineLayers.enumerated() {
            let x = index == 0 ? columns.gutter : columns.lines[index - 1]
            layer.backgroundColor = (index == 0 ? PaperPalette.lineStrong : PaperPalette.line).cgColor
            layer.frame = CGRect(x: x * zoom - line / 2, y: 0, width: line, height: height)
        }
    }

    /// The first `count` sublayers of `parent`, made or removed so there are exactly that many.
    private static func layers(of parent: CALayer, count: Int) -> [CALayer] {
        var current = parent.sublayers ?? []
        while current.count < count {
            let layer = CALayer()
            parent.addSublayer(layer)
            current.append(layer)
        }
        while current.count > count {
            current.removeLast().removeFromSuperlayer()
        }
        return current
    }
}
#endif
