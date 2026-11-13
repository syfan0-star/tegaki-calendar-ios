import Holidays
import Layout
import SwiftUI
import UIKit

/// The fixed all-day band of the week / day page (M4B_CONTRACT §2.2, DESIGN §2.4 / §2.5): under the
/// sticky header, above the canvas, outside the paper, like the web version's .sh-allday and the
/// iOS Calendar app. It cannot be written on (a SwiftUI view: neither the Pencil nor a finger
/// reaches the paper through it, M4B-16).
///
/// Every number and colour class comes from `AllDayBandLayout` (担当 K) and `AllDayBandMetrics`:
/// the x positions follow the paper's horizontal offset and zoom through `viewport` (D2: the
/// 「終日」 gutter flows left with the paper), the lanes have point minimums (M4B-1), the height is
/// capped at 35 % of the page's visible height and the band scrolls inside past that. A bar opens
/// the editor (`onBarTap`), the empty part of a column creates an all-day event on that day
/// (`onColumnTap`, M4B-14); a tap on the gutter does nothing. Without all-day events the band is
/// an `EmptyView` (height 0, no line; M4B-2). The view never judges weekdays or holidays itself:
/// `band.tones` and `band.todayColumn` decide the column tints.
///
/// M4c (M4C contract §4.2 / §5.2): on the week page a double tap on a column goes to that day's page
/// (`onColumnDoubleTap`, D5 / M4C-15; a SwiftUI `TapGesture` cannot tell the Pencil from a finger,
/// so the Pencil's double tap goes too). The day page's band keeps the plain tap (a double tap does
/// nothing there, so the tap is not delayed either). While a pinch is in progress the screen passes
/// `laneZoom` (the zoom at the start of the pinch): the lane height, gap and text are frozen at it so
/// the band's height does not change under the pinch (M4C-27); the column x and widths keep
/// following `viewport` (D6).
struct AllDayBandView: View {
    var band: AllDayBandLayout
    /// The paper's horizontal offset, zoom and container width (§1.1).
    var viewport: PaperViewport
    /// Height (pt) of the area holding the band and the canvas: the base of the 35 % cap.
    var pageHeight: CGFloat
    /// The zoom the lane height / gap / text are computed at instead of `viewport.zoom` (frozen
    /// during a pinch, M4C-27); nil = `viewport.zoom`.
    var laneZoom: CGFloat? = nil
    /// 1.3 (docs/M7C_CONTRACT.md §3.8): the window of joined weeks or days whose bands (`span.bands`, the
    /// lanes packed over the window's days, `AllDayBandLanes`) are shown side by side, each page's columns,
    /// 「終日」 and bars from its slot's x, with `viewport` over the whole window. Every page has the window's
    /// lane count, so one band height; an event across a boundary keeps its lane and continues square into
    /// the next page. Only on the joined path (`PaperSpan.isJoined`) does 「終日」 give way where it does not
    /// fit its time column (`spanGutterLabel`). nil: `band` alone, 1.2.3's band. A window of one page draws
    /// its one band as `band` would be drawn.
    var span: PaperSpan? = nil
    /// eventId → the edit sheet.
    var onBarTap: (String) -> Void
    /// A column's empty part → the create sheet for that day's all-day event.
    var onColumnTap: (DayKey) -> Void
    /// A finger (or Pencil) double tap on a week column → that day's page (M4C-15).
    var onColumnDoubleTap: (DayKey) -> Void = { _ in }

    /// Corner radius of a bar (0 on a side that continues past the band's range).
    static let barCorner: CGFloat = 4
    /// Horizontal padding of a bar's text, and the right padding of 「終日」.
    static let textPad: CGFloat = 6

    /// 1.3: one band of what the view shows and the paper x (lu) its page starts at.
    struct PlacedBand {
        /// The page's slot in the window (0 for `band` alone).
        var slot: Int
        var band: AllDayBandLayout
        /// `PaperSpan.origin(ofSlot:)`; 0 for `band` alone.
        var origin: CGFloat
    }

    /// The bands shown: `span`'s, each at its slot's x, or `band` alone at x 0 (1.2.3).
    static func placedBands(band: AllDayBandLayout, span: PaperSpan?) -> [PlacedBand] {
        guard let span = span, !span.bands.isEmpty else { return [PlacedBand(slot: 0, band: band, origin: 0)] }
        return span.bands.enumerated().map { PlacedBand(slot: $0.offset, band: $0.element, origin: span.origin(ofSlot: $0.offset)) }
    }

    private var placed: [PlacedBand] {
        Self.placedBands(band: band, span: span)
    }

    /// The lanes of the shown bands (the window's bands all have the window's count): `band.laneCount` alone.
    private var laneCount: Int {
        placed.reduce(0) { max($0, $1.band.laneCount) }
    }

    /// The kind whose lane gap and text size the band uses: the window's, or `band`'s.
    private var bandKind: PageKind {
        placed.first?.band.kind ?? band.kind
    }

    private var metrics: AllDayBandMetrics.Metrics {
        AllDayBandMetrics.metrics(kind: bandKind, laneCount: laneCount, zoom: laneZoom ?? viewport.zoom, pageHeight: pageHeight)
    }

    /// The container width; never negative or non-finite (a `frame` must not get those).
    private var width: CGFloat {
        viewport.width.isFinite ? max(0, viewport.width) : 0
    }

    var body: some View {
        if laneCount > 0 {
            let metrics = self.metrics
            ScrollView(.vertical, showsIndicators: true) {
                content(metrics)
                    .frame(width: width, height: metrics.contentHeight, alignment: .topLeading)
            }
            .scrollDisabled(!metrics.scrollsInside)
            .frame(width: width, height: metrics.visibleHeight)
            .background(paperColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(lineStrongColor).frame(height: 1)
            }
            .clipped()
        }
    }

    // MARK: - Content

    /// The columns (tint + tap target), the 「終日」 gutter and the bars, all placed by paper x
    /// through `viewport` and by lane through `metrics`. 1.3: of every placed band in turn (the columns of
    /// all, then the gutters, then the bars), each moved by its page's x; `band` alone is at x 0.
    private func content(_ metrics: AllDayBandMetrics.Metrics) -> some View {
        let placed = self.placed
        let joined = span?.isJoined == true
        return ZStack(alignment: .topLeading) {
            ForEach(placed, id: \.slot) { page in
                ForEach(page.band.days.indices, id: \.self) { index in
                    column(page, index, metrics)
                }
            }
            ForEach(placed, id: \.slot) { page in
                gutterLabel(page, joined: joined, metrics)
            }
            ForEach(placed, id: \.slot) { page in
                ForEach(page.band.bars) { bar in
                    barView(page, bar, metrics)
                }
            }
        }
        .frame(width: width, height: metrics.contentHeight, alignment: .topLeading)
    }

    /// One day column: the today / weekend tint over the whole content height, tappable for 「その日の
    /// 終日予定を追加」. On the week page a double tap goes to the day page instead (M4C-15): the two
    /// taps are one exclusive gesture, so the single tap waits for the double tap to fail (about 0.3 s,
    /// M4C-6); the day page's band keeps the plain tap.
    private func column(_ page: PlacedBand, _ index: Int, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let band = page.band
        let day = band.days[index]
        let x = index < band.columnMinX.count ? viewport.x(ofPaper: page.origin + band.columnMinX[index]) : 0
        let columnWidth = max(0, viewport.width(ofPaper: band.columnWidth))
        let shape = Rectangle()
            .fill(Self.columnTint(band, index) ?? Color.clear)
            .frame(width: columnWidth, height: metrics.contentHeight)
            .contentShape(Rectangle())
        return Group {
            if band.kind == .day {
                shape.onTapGesture { onColumnTap(day) }
            } else {
                shape
                    .gesture(
                        TapGesture(count: 2).onEnded { onColumnDoubleTap(day) }
                            .exclusively(before: TapGesture(count: 1).onEnded { onColumnTap(day) })
                    )
                    // VoiceOver's activate is the single tap (`.gesture` does not add one itself).
                    .accessibilityAction { onColumnTap(day) }
            }
        }
        .accessibilityLabel(Self.columnLabel(day))
        .accessibilityAddTraits(.isButton)
        .offset(x: x)
    }

    /// 「終日」 in the gutter `[paper 0, paper gutter]`, right-aligned, on the first lane. It moves
    /// with the paper (D2), so it leaves the screen when the paper is scrolled to the right. 1.2 (F-7):
    /// a language whose word does not fit the gutter takes the short form, or shows nothing; ja is
    /// 1.1's, also where the gutter cuts it. 1.3: in every page's time column of the window, and on the
    /// joined path only where it fits whole (`spanGutterLabel`; a cut 「終日」 in each of 9 narrow gutters
    /// would be a row of marks).
    @ViewBuilder
    private func gutterLabel(_ page: PlacedBand, joined: Bool, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let gutterWidth = max(0, viewport.width(ofPaper: page.band.gutter))
        let label = joined
            ? Self.spanGutterLabel(widthPoints: gutterWidth, language: L.language)
            : PaperWords.allDayLabel(widthPoints: gutterWidth, fontSize: AllDayBandMetrics.labelPoints, L.language)
        if let label = label {
            Text(label)
                .font(.system(size: AllDayBandMetrics.labelPoints))
                .foregroundStyle(ink3)
                .lineLimit(1)
                .padding(.trailing, Self.textPad)
                .frame(width: gutterWidth, height: metrics.lane, alignment: .trailing)
                .clipped()
                .accessibilityHidden(true)
                .offset(x: viewport.x(ofPaper: page.origin), y: metrics.laneTop(0))
        }
    }

    /// 1.3 (the lead's decision 4): 「終日」 of a joined page's gutter — `PaperWords.allDayLabel`'s word, in
    /// every language (ja included) only when it fits `widthPoints` with `textPad` and 2 pt to spare, else
    /// nothing.
    static func spanGutterLabel(widthPoints: CGFloat, language: UILanguage) -> String? {
        guard widthPoints.isFinite,
              let label = PaperWords.allDayLabel(widthPoints: widthPoints, fontSize: AllDayBandMetrics.labelPoints, language) else { return nil }
        let font = UIFont.systemFont(ofSize: AllDayBandMetrics.labelPoints)
        return PaperText.naturalWidth(of: label, font: font) + textPad + 2 <= widthPoints ? label : nil
    }

    /// One bar: the event's colour, its title cut at the bar's edge (D4), round corners except on a
    /// side that continues past the band. A button: a Pencil tap works like a finger tap.
    private func barView(_ page: PlacedBand, _ bar: AllDayBandBar, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let x = viewport.x(ofPaper: page.origin + bar.minX)
        let barWidth = max(0, viewport.width(ofPaper: bar.maxX - bar.minX))
        let shape = Self.barShape(bar)
        let fill = Color(uiColor: PaperPalette.color(hex: bar.colorHex))
        let text = Color(uiColor: PaperPalette.readableText(on: bar.colorHex))
        return Button {
            onBarTap(bar.eventId)
        } label: {
            Text(bar.title)
                .font(.system(size: metrics.text, weight: .semibold))
                .foregroundStyle(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Self.textPad)
                .frame(width: barWidth, height: metrics.lane, alignment: .leading)
                .background(shape.fill(fill))
                .clipShape(shape)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.barLabel(bar))
        .offset(x: x, y: metrics.laneTop(bar.lane))
    }

    // MARK: - Helpers

    /// The tint of column `index`: today wins (`todayTint` on the week page, `todayTintSoft` on the
    /// day page), then Saturday / Sunday / holiday (`weekendTint` / `weekendTintSoft`, the same as
    /// the paper's columns); nil for a plain weekday.
    private static func columnTint(_ band: AllDayBandLayout, _ index: Int) -> Color? {
        let soft = band.kind == .day
        if band.todayColumn == index {
            return Color(uiColor: soft ? PaperPalette.todayTintSoft : PaperPalette.todayTint)
        }
        guard index < band.tones.count, band.tones[index] != .normal else { return nil }
        return Color(uiColor: soft ? PaperPalette.weekendTintSoft : PaperPalette.weekendTint)
    }

    /// Round corners of `barCorner`, squared off on the side the event continues past.
    static func barShape(_ bar: AllDayBandBar) -> UnevenRoundedRectangle {
        let left: CGFloat = bar.continuesLeft ? 0 : barCorner
        let right: CGFloat = bar.continuesRight ? 0 : barCorner
        return UnevenRoundedRectangle(
            topLeadingRadius: left,
            bottomLeadingRadius: left,
            bottomTrailingRadius: right,
            topTrailingRadius: right
        )
    }

    /// 「題名（予定を編集）」
    static func barLabel(_ bar: AllDayBandBar) -> String {
        L.format("allday.bar.spoken", bar.title)
    }

    /// 「2026年10月7日(水) の終日予定を追加」
    static func columnLabel(_ day: DayKey) -> String {
        L.format("allday.column.spoken", DateText.spokenDay(day, L.language))
    }

    private var paperColor: Color { Color(uiColor: PaperPalette.paper) }
    private var ink3: Color { Color(uiColor: PaperPalette.ink3) }
    private var lineStrongColor: Color { Color(uiColor: PaperPalette.lineStrong) }
}

/// 1.3 (docs/M7C_CONTRACT.md §3.8, B_DESIGN.md §3.1): the lanes of a window's all-day band through one
/// session. The window's bands are laid out together over all of its days (`AllDayBandEngine.pages`), so
/// an event across the boundary of two pages keeps one lane (packed page by page, its lanes could swap
/// there). The lane count is decided again only when the window is laid out — at a shift, a reopening, an
/// event change — never while the band merely slides sideways, and it never goes down in a session: each
/// layout asks for at least the most lanes the session has shown (`minimumLaneCount`). A new session (the
/// screen's new `SpanSession`) starts a new value at 0. The pages' event lists may simply be put one after
/// another: an event in several of them counts once (`bands`). Nothing is stored.
struct AllDayBandLanes: Equatable {
    /// The most lanes this session has shown (0 before the first layout).
    private(set) var floor = 0

    init() {}

    /// The bands of a window whose days, left to right, are `days` (`PaperSpan.days`, or the days of the
    /// session's `SpanLayout` pages): one band per week (7 days each) or per day, every one with the
    /// window's lane count, at least `floor`; `floor` becomes that count.
    ///
    /// `events` may name an event more than once: the session keeps its events page by page
    /// (`[pageId: [LayoutEvent]]`, §3.8), and an event across two pages is in both lists. They are taken once
    /// per `LayoutEvent.id`, the first of each in the given order (`uniqueEvents`, as `EventKitService.events`
    /// does within one query), so the pages' lists put one after another give the window one bar per page
    /// for each event and the lane count of the events themselves. Without this the packing would place
    /// every copy (`MonthLayoutEngine.packAllDayLanes` keeps them all): the event twice on each page, on two
    /// lanes, with one lane too many — and two bars with one id in `ForEach(page.band.bars)`.
    mutating func bands(_ kind: PageKind, days: [DayKey], events: [LayoutEvent], now: Date, calendar: Calendar = DayKey.deviceCalendar,
                        holidays: HolidayCalendar) -> [AllDayBandLayout] {
        let bands = AllDayBandEngine.pages(kind, days: days, events: Self.uniqueEvents(events), now: now, calendar: calendar,
                                           holidays: holidays, minimumLaneCount: floor)
        floor = max(floor, bands.reduce(0) { max($0, $1.laneCount) })
        return bands
    }

    /// `events` with each `LayoutEvent.id` once, the first of it, in their order.
    static func uniqueEvents(_ events: [LayoutEvent]) -> [LayoutEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.id).inserted }
    }
}
