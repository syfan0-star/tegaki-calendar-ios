import Foundation
import CoreGraphics

/// The device a window is sized for (docs/M7C_CONTRACT.md §3.6). The window size is fixed per class
/// and orientation (not computed from the live paper area, so a band that gains a lane never changes
/// it); `SpanPlan.referenceViewport` holds the paper area each class stands for. The iPhone Duo's inner
/// screen is 1.4's (§1.6; its row of the table is checked on the radius rule only).
public enum SpanDeviceClass: String, CaseIterable, Sendable, Codable {
    case iPhone
    /// iPad mini (744 × 1133 pt).
    case iPadMini
    /// The 11-inch iPads (iPad Air 11 820 × 1180, iPad Pro 11 834 × 1210).
    case iPad11
    /// The 13-inch iPads (1024 × 1366, iPad Pro 13 1032 × 1376).
    case iPad13

    /// The class of a screen (pt, either orientation): every iPhone is `.iPhone`; an iPad by its short
    /// side: up to 780 the mini, up to 900 the 11-inch, above it the 13-inch.
    public init(screen: CGSize, isPad: Bool) {
        guard isPad else {
            self = .iPhone
            return
        }
        let short = min(abs(screen.width), abs(screen.height))
        if !(short > 780) {
            self = .iPadMini
        } else if short <= 900 {
            self = .iPad11
        } else {
            self = .iPad13
        }
    }
}

/// Portrait or landscape (docs/M7C_CONTRACT.md §3.6).
public enum SpanOrientation: String, CaseIterable, Sendable, Codable {
    case portrait, landscape

    /// Landscape when the screen is wider than it is tall.
    public init(screen: CGSize) {
        self = screen.width > screen.height ? .landscape : .portrait
    }
}

/// The plan of one kind of joined pages (1.3, docs/M7C_CONTRACT.md §2.1, §3.2, §3.6, §3.16; B_DESIGN.md
/// §2.3, §2.4, §6.2): page numbers and page ids both ways, where each page of the window sits, which
/// page owns a point, the focus, the window size, the shift, the fling and the stroke estimate. Pure
/// functions; one plan is one week start (K-11: a window never mixes the two shapes of the week), so
/// the app always passes its setting (lint L-13 checks `SpanPlan(` for `weekStart:`).
///
/// Coordinates: the window's pages sit side by side from x 0 (lu) without gaps, each `pageWidth` wide,
/// so page slot k (k = 0 for the window's first page) spans [k × W, (k + 1) × W). `owner(ofCenterX:)`
/// and `focus(midX:previous:)` work in slots; `origin(of:around:)` in page numbers. The canvas's
/// offsets (`shiftAmount`, `flingTarget`) are points: lu × zoom.
public struct SpanPlan: Sendable, Equatable {
    public let kind: PageKind
    public let weekStart: WeekStart
    public let deviceClass: SpanDeviceClass
    public let orientation: SpanOrientation

    public init(kind: PageKind, weekStart: WeekStart, deviceClass: SpanDeviceClass, orientation: SpanOrientation) {
        self.kind = kind
        self.weekStart = weekStart
        self.deviceClass = deviceClass
        self.orientation = orientation
    }

    // MARK: Fixed numbers (§3.16)

    /// The focus changes only when the middle of the screen is 6 % of a page past the focus page's edge
    /// (B_DESIGN.md:181, 5–8 %; the prototype may change it).
    public static let focusHysteresis: CGFloat = 0.06

    /// A stop this close to an aligned position (a fraction of the screen's width) snaps to it
    /// (B_DESIGN.md:276; the prototype may change it).
    public static let snapFraction: CGFloat = 0.06

    /// The speed (pt per ms, the unit of `scrollViewWillEndDragging`'s velocity) from which a release
    /// at a page-fitting zoom is a fling to the next page; slower is a stop where it is. Not a number
    /// of the contract: chosen here, measured in the prototype (§4.6).
    public static let flingVelocity: CGFloat = 0.3

    /// The bytes one stroke takes at least in a page file (LZFSE; 40 points ≈ 0.26 KB, 120 points ≈
    /// 0.76 KB, B_DESIGN.md:519): the estimate divides by 0.25 KB, so it counts more strokes, not fewer.
    public static let bytesPerStroke = 250

    /// The most strokes a window may hold before stage 2 brings the kind back to one page at a time
    /// (D18, §3.15): iPad 20,000, iPhone 12,000. To be measured again in the prototype.
    public static let windowStrokeCap: (iPad: Int, iPhone: Int) = (iPad: 20_000, iPhone: 12_000)

    /// `windowStrokeCap` of this plan's device.
    public var strokeCap: Int {
        deviceClass == .iPhone ? Self.windowStrokeCap.iPhone : Self.windowStrokeCap.iPad
    }

    /// The strokes a page file of `fileBytes` may hold, counted high: ⌈bytes ÷ 250⌉ (0 for an empty or
    /// missing file). Replaced by the real count once the page is read (§3.15).
    public static func estimatedStrokes(fileBytes: Int) -> Int {
        guard fileBytes > 0 else { return 0 }
        return (fileBytes - 1) / bytesPerStroke + 1
    }

    // MARK: Page numbers and page ids (§3.2)

    /// The width of one page (lu): week, month and year 1400, day 1000.
    public var pageWidth: CGFloat {
        ZoomPolicy.paperWidth(kind)
    }

    /// The number of a page id of this plan's kind and shape: day → the day number (days since
    /// 1970-01-01); week → ⌊first.dayNumber ÷ 7⌋ (1970-01-01 is a Thursday, so a Monday is 7n + 4 and a
    /// Sunday 7n + 3, the same n for the Monday and the Sunday before it); month → year × 12 + month − 1;
    /// year → the year. nil for another kind, a week id of the other week start (or of a day that
    /// starts neither), and anything `PageNavigation.parse` does not read (a prefixed name, a virtual id).
    public func index(of pageId: String) -> Int? {
        guard let parsed = PageNavigation.parse(pageId: pageId), parsed.kind == kind else { return nil }
        return number(of: parsed.focus, normalized: false)
    }

    /// The number of the page holding `day` (a week by this plan's week start).
    public func index(containing day: DayKey) -> Int {
        number(of: day, normalized: true) ?? 0
    }

    private func number(of day: DayKey, normalized: Bool) -> Int? {
        switch kind {
        case .day:
            return day.dayNumber
        case .week:
            let first = normalized ? weekStart.firstDay(of: day) : day
            guard first.weekday == weekStart.firstWeekday else { return nil }
            return Self.floorDiv(first.dayNumber, 7)
        case .month:
            return day.year * 12 + day.month - 1
        case .year:
            return day.year
        }
    }

    /// The first day of page `index`: the day; the week's first day, `index × 7 + 4` (a Monday) or
    /// `+ 3` (a Sunday); the 1st of the month; January 1.
    public func firstDay(at index: Int) -> DayKey {
        switch kind {
        case .day:
            return DayKey(dayNumber: index)
        case .week:
            return DayKey(dayNumber: index * 7 + (weekStart == .monday ? 4 : 3))
        case .month:
            let year = Self.floorDiv(index, 12)
            return DayKey(year: year, month: index - year * 12 + 1, day: 1)
        case .year:
            return DayKey(year: index, month: 1, day: 1)
        }
    }

    /// The page id of page `index`, as `PageNavigation.pageId` writes it with this plan's week start
    /// (the inverse of `index(of:)` for the years 1…9999 the ids can spell).
    public func pageId(at index: Int) -> String {
        PageNavigation.pageId(kind, focus: firstDay(at: index), weekStart: weekStart)
    }

    // MARK: Where pages sit (§3.2, D15)

    /// The x (lu) of page `index`'s left edge in the window around `focus`: (index − (focus − R)) × W.
    public func origin(of index: Int, around focus: Int) -> CGFloat {
        CGFloat(index - (focus - radius)) * pageWidth
    }

    /// The slot of the page owning x (lu): the half-open [k × W, (k + 1) × W), so x exactly on a
    /// boundary belongs to the page on its right (D15). Below 0 and past the window it goes on
    /// counting (−1, count, …; the caller clamps or drops). A centre that is not finite → 0 (such a
    /// stroke is dropped anyway: `SpanLayout.drop` says `.outsidePaper`).
    public func owner(ofCenterX x: CGFloat) -> Int {
        guard x.isFinite else { return 0 }
        let w = pageWidth
        let q = (x / w).rounded(.down)
        guard q.magnitude < CGFloat(Int.max / 2) else { return x < 0 ? Int.min / 2 : Int.max / 2 }
        var k = Int(q)
        if x < CGFloat(k) * w { k -= 1 }
        if x >= CGFloat(k + 1) * w { k += 1 }
        return k
    }

    /// The focus slot when the middle of the screen is at `midX` (lu, `(offset.x + width / 2) / zoom`)
    /// and the focus was `previous`: it stays while midX is in [X − h, X + W + h) of the previous page
    /// (X its left edge, h = 6 % of W), so the title does not flip back and forth over a boundary; past
    /// that it is the owner of midX. A midX that is not finite keeps `previous`.
    public func focus(midX: CGFloat, previous: Int) -> Int {
        guard midX.isFinite else { return previous }
        let w = pageWidth
        let left = CGFloat(previous) * w
        let h = Self.focusHysteresis * w
        if midX >= left - h && midX < left + w + h { return previous }
        return owner(ofCenterX: midX)
    }

    // MARK: Window size (§3.6, B_DESIGN.md §6.2)

    /// The pages one sees at once at the lower zoom limit, V = viewport width ÷ (page width × the
    /// lowest zoom), with 1.1.1's lowest zoom: `ZoomPolicy.bounds(…).min` of the page's base size (for
    /// the week and the day the overview is the base size, 1400 × 1920 and 1000 × 2400; the free memo
    /// below 24:00 is reached by scrolling, K-6). 0 for a viewport that is not usable.
    public static func visiblePages(_ kind: PageKind, viewport: CGSize) -> CGFloat {
        guard viewport.width.isFinite, viewport.width > 0, viewport.height.isFinite, viewport.height > 0 else { return 0 }
        let zoom = ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: viewport).min
        guard zoom.isFinite, zoom > 0 else { return 0 }
        return viewport.width / (ZoomPolicy.paperWidth(kind) * zoom)
    }

    /// R = ⌈(V − 0.05) / 2 + 1⌉ (B_DESIGN.md §6.2, measured in V2Probe §7): the pages on each side of
    /// the focus, one more than half of what is visible, so a fling of one page never shows the end of
    /// the window. At least 1; a V that is not finite counts as 0.
    public static func radius(forVisiblePages v: CGFloat) -> Int {
        let visible = v.isFinite ? max(0, v) : 0
        return max(1, Int(((visible - 0.05) / 2 + 1).rounded(.up)))
    }

    /// The paper area (pt; the all-day band of one lane taken off for the week and the day) each class
    /// stands for, where the table of §3.6 comes from. Portrait: CI's measurement (docs/M4C.md §3,
    /// docs/R1_1_1.md §2.2: iPhone 17, iPad mini (A17 Pro), iPad Pro 11-inch, iPad Pro 13-inch).
    /// Landscape: docs/M4C_CONTRACT.md §1.2's estimates, as B_DESIGN.md §6.2 used them (CI cannot take
    /// an iPad in landscape, §4.5, so KitChecks is the only automatic check of these rows).
    public static func referenceViewport(_ kind: PageKind, deviceClass: SpanDeviceClass, orientation: SpanOrientation) -> CGSize {
        // (width, [month, week, day, year] heights)
        let row: (CGFloat, [CGFloat])
        switch (deviceClass, orientation) {
        case (.iPhone, .portrait): row = (402, [590.67, 540, 536, 569])
        case (.iPadMini, .portrait): row = (744, [928.5, 878, 874, 907])
        case (.iPad11, .portrait): row = (834, [1005.5, 955, 951, 984])
        case (.iPad13, .portrait): row = (1032, [1171.5, 1121, 1117, 1150])
        case (.iPhone, .landscape): row = (874, [230, 205, 205, 230])
        case (.iPadMini, .landscape): row = (1133, [550, 525, 525, 550])
        case (.iPad11, .landscape): row = (1210, [640, 615, 615, 640])
        case (.iPad13, .landscape): row = (1366, [830, 805, 805, 830])
        }
        let height: CGFloat
        switch kind {
        case .month: height = row.1[0]
        case .week: height = row.1[1]
        case .day: height = row.1[2]
        case .year: height = row.1[3]
        }
        return CGSize(width: row.0, height: height)
    }

    /// V of this plan's device and orientation.
    public var visiblePages: CGFloat {
        Self.visiblePages(kind, viewport: Self.referenceViewport(kind, deviceClass: deviceClass, orientation: orientation))
    }

    /// R of this plan (the window is 2R + 1 pages): iPad 11 and 13 portrait 5 weeks / 7 days and
    /// landscape 7 / 9, mini portrait 5 / 5 and landscape 7 / 9, iPhone portrait 5 / 5 and landscape
    /// 9 / 15 (§3.6; KitChecks fixes every row).
    public var radius: Int {
        Self.radius(forVisiblePages: visiblePages)
    }

    /// 2R + 1.
    public var windowSize: Int {
        2 * radius + 1
    }

    /// The page numbers of the window around `focus`: focus − R … focus + R.
    public func window(around focus: Int) -> ClosedRange<Int> {
        (focus - radius)...(focus + radius)
    }

    // MARK: Shift and fling (§3.6)

    /// How far (pt) the content offset moves back when the window shifts by `pages` pages at `zoom`:
    /// pages × W × zoom, so nothing on screen moves (11-inch portrait overview: week 696 pt, day 396 pt).
    /// 0 when the zoom is not finite or not positive.
    public func shiftAmount(pages: Int, zoom: CGFloat) -> CGFloat {
        guard zoom.isFinite, zoom > 0 else { return 0 }
        return CGFloat(pages) * pageWidth * zoom
    }

    /// Where a drag released at content offset `offsetX` (pt) comes to rest (P-B5 ア, §3.6). The
    /// aligned positions are where a page sits as the overview shows it: centred when the page fits the
    /// screen (W × zoom ≤ width), else its left edge on the screen's left edge or its right edge on the
    /// screen's right edge.
    /// - A page fits and |velocity| ≥ `flingVelocity`: the next aligned position in the direction of
    ///   the velocity (positive: towards later pages), so a fling turns exactly one page from where the
    ///   finger left it (from an aligned position, the neighbour page).
    /// - Otherwise the drag stops where UIKit would stop it (`proposedX`, else `offsetX`), and snaps to
    ///   the nearest aligned position when it is at most 6 % of the screen's width away; zoomed in, a
    ///   fling flows freely to `proposedX` (UIKit clamps it to the window).
    /// `viewportWidth` nil is the reference width of the plan's device. Not finite or not positive
    /// inputs → `proposedX ?? offsetX`.
    public func flingTarget(offsetX: CGFloat, velocity: CGFloat, zoom: CGFloat, viewportWidth: CGFloat? = nil, proposedX: CGFloat? = nil) -> CGFloat {
        let stop = proposedX ?? offsetX
        let vw = viewportWidth ?? Self.referenceViewport(kind, deviceClass: deviceClass, orientation: orientation).width
        guard offsetX.isFinite, stop.isFinite, velocity.isFinite, zoom.isFinite, zoom > 0, vw.isFinite, vw > 0 else { return stop }
        let page = pageWidth * zoom
        let fits = page <= vw + 1e-9
        if fits && abs(velocity) >= Self.flingVelocity {
            // Aligned positions a_k = (k + 0.5) × page − vw / 2; t is offsetX's place among them.
            let t = (offsetX + vw / 2) / page - 0.5
            let k = velocity > 0 ? (t + 1e-9).rounded(.down) + 1 : (t - 1e-9).rounded(.up) - 1
            return (k + 0.5) * page - vw / 2
        }
        if !fits && abs(velocity) >= Self.flingVelocity {
            return stop
        }
        var candidates: [CGFloat] = []
        if fits {
            let k = ((stop + vw / 2) / page - 0.5).rounded()
            candidates = [k - 1, k, k + 1].map { ($0 + 0.5) * page - vw / 2 }
        } else {
            let k = (stop / page).rounded(.down)
            for j in [k - 1, k, k + 1, k + 2] {
                candidates.append(j * page)
                candidates.append(j * page - vw)
            }
        }
        guard let nearest = candidates.min(by: { abs($0 - stop) < abs($1 - stop) }) else { return stop }
        return abs(nearest - stop) <= Self.snapFraction * vw + 1e-9 ? nearest : stop
    }

    /// ⌊a ÷ b⌋ for b > 0, also for a negative a.
    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
}
