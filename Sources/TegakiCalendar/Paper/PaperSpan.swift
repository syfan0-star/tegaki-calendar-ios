import Layout
import UIKit

/// 1.3 (docs/M7C_CONTRACT.md §3.8, §3.13, D2, D16; B_DESIGN.md §3.1–§3.3): the pages of a window of joined
/// weeks or days, as the paper (`PaperView.span`), the fixed heading (`StickyHeaderView.span`) and the
/// all-day band (`AllDayBandView.span`) show them. The pages sit side by side from paper x 0 without a gap,
/// slot k's left edge at k × the page width — the slots of the session's `SpanLayout`
/// (`SpanLayout.origin(ofSlot:)`): every week 1,400 × 1,920 lu, every day 1,000 lu wide with its free memo
/// below 24:00 lined up to the window's floor (D16: the session lays the days out with
/// `DayLayoutInput.extraFloor` from `SpanAlign.dayFloors`; the paper draws what each layout says, so the
/// memo runs on as one band). Only weeks and days are joined in 1.3 (D2): a month or a year never makes one.
///
/// `bands` are the window's all-day bands, one per page, with the lanes packed over the whole run of days
/// at once (`AllDayBandLanes`, `AllDayBandEngine.pages`), so an event across a boundary keeps its lane.
/// `focus` is the slot of the focus page (the page of the title, of the narrow two-row heading of
/// `CalendarRootScreen.compactWidth` and of the PDF; the screen keeps choosing them from it, §3.13).
///
/// Nothing here is stored or synced (K-5) and no page id or name is made: the value only places what the
/// pages' own layouts say. A window of one page shows what that page shows alone (each view's comment
/// says how), so the old path and a window of one page give 1.2.3's output.
struct PaperSpan: Equatable {
    /// `.week` or `.day`.
    let kind: PageKind
    /// Left to right, slot 0 first; all of `kind`.
    let pages: [PaperContent]
    /// One per page, in the same order (`AllDayBandEngine.pages`: every band has the window's lane count).
    let bands: [AllDayBandLayout]
    /// The slot of the focus page, 0 ≤ focus < pages.count.
    let focus: Int

    /// nil unless there is at least one page, every page is a week or every page is a day, and there is one
    /// band per page of the same kind. `focus` is kept on the window.
    init?(pages: [PaperContent], bands: [AllDayBandLayout], focus: Int) {
        guard let first = pages.first?.kind, first == .week || first == .day,
              pages.allSatisfy({ $0.kind == first }), bands.count == pages.count,
              bands.allSatisfy({ $0.kind == first }) else { return nil }
        kind = first
        self.pages = pages
        self.bands = bands
        self.focus = min(max(0, focus), pages.count - 1)
    }

    /// The window of the session's `SpanLayout`: its pages as the paper draws them (a week page →
    /// `.week`, a day page → `.day`), with `bands` (`AllDayBandLanes.bands`) and the focus slot. nil when a
    /// page of the layout is neither (the month and the year are not joined in 1.3) or the counts differ.
    init?(layout: SpanLayout, bands: [AllDayBandLayout], focus: Int) {
        var contents: [PaperContent] = []
        for page in layout.pages {
            if let week = page as? WeekPageLayout {
                contents.append(.week(WeekPaperContent(layout: week)))
            } else if let day = page as? DayPageLayout {
                contents.append(.day(DayPaperContent(layout: day)))
            } else {
                return nil
            }
        }
        self.init(pages: contents, bands: bands, focus: focus)
    }

    /// The window of one page: the page and its own band (the band 1.2.3 lays out for it alone). nil for a
    /// month or a year.
    static func single(_ paper: PaperContent) -> PaperSpan? {
        guard let band = paper.allDayBand else { return nil }
        return PaperSpan(pages: [paper], bands: [band], focus: 0)
    }

    /// More than one page: the joined path of the heading and the band (their thinning, the month over the
    /// week's time column). A window of one page is shown as the page alone.
    var isJoined: Bool {
        pages.count > 1
    }

    /// The width of one page (lu): week 1,400, day 1,000 (`ZoomPolicy.paperWidth`, `SpanPlan.pageWidth`).
    var pageWidth: CGFloat {
        ZoomPolicy.paperWidth(kind)
    }

    /// The x (lu) of slot `slot`'s left edge: slot × `pageWidth`, as `SpanLayout.origin(ofSlot:)`.
    func origin(ofSlot slot: Int) -> CGFloat {
        CGFloat(slot) * pageWidth
    }

    /// The whole window (lu): the pages' widths side by side, the tallest page's height (the joined days
    /// are equally tall when the session gives them the floor, D16).
    var size: CGSize {
        CGSize(width: CGFloat(pages.count) * pageWidth, height: pages.reduce(CGFloat(0)) { max($0, $1.size.height) })
    }

    /// The date labels of slot `slot`'s page (week: 7, day: 1), as its layout gives them.
    func dateLabels(ofSlot slot: Int) -> [DateLabel] {
        guard slot >= 0, slot < pages.count else { return [] }
        return pages[slot].layout.dateLabels
    }

    /// Every day of the window, left to right (the run of days `AllDayBandLanes.bands` packs).
    var days: [DayKey] {
        pages.flatMap { Self.days(of: $0) }
    }

    /// The days of one page: a week's 7 (from its first day), a day's one; none for a month or a year.
    static func days(of paper: PaperContent) -> [DayKey] {
        switch paper {
        case .week(let content): return content.layout.days
        case .day(let content): return [content.layout.day]
        case .month, .year: return []
        }
    }
}
