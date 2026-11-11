#if SPAN_PROTOTYPE
import CoreGraphics
import Foundation
import InkModel
import Layout
import UIKit

// The prototype's sample images (1.3, docs/M7C_CONTRACT.md §4.5, §10.5, §12.2 S2). The CI's span-shots job launches
// the prototype build with `--screenshot-mode --screenshot-month 2026-10 --screenshot-sheet info --screenshot-prototype
// <scene>`: screenshot mode opens 設定 › 情報 over the month page (its inert engine and demo store; nothing is stored),
// and the prototype's row there (`SpanPrototypeEntryRow`, the last row of 情報) opens the prototype screen by itself
// once it is on screen, in the fixed state of the scene — 「今日」 is screenshot mode's (2026-10-07 10:00), the
// prototype's own folder holds the same sample strokes every time (`seed`), the measurements are hidden and the guide
// card stays only in its own scene. Without the argument (and in the normal build, where none of this exists) nothing
// changes. Compiled only into the prototype build (`SPAN_PROTOTYPE`); it goes away with the prototype (S6).

/// `--screenshot-prototype <scene>`: the scenes of §4.5 and how the prototype screen opens for each.
enum SpanPrototypeShot {
    /// What one photo shows (§4.5). The band scenes open with the boundary between this week and the next in the
    /// middle of the screen, the sample strokes crossing it.
    enum Scene: String, CaseIterable, Sendable {
        /// The week band, the boundary in the middle (an iPhone in landscape: twice the opening zoom, 7:00 at the top).
        case boundary
        /// The same with weeks that start on Sunday: the boundary is Saturday → Sunday.
        case sunday
        /// The overview (一覧, P-B10 ア): this week in the middle at the opening zoom, which is also the lowest.
        case overview
        /// An iPhone in landscape at the lowest zoom, 「今のまま」 (P-B6 ア: the 24 hours, the window's weeks small).
        case landscapeNow = "landscape-now"
        /// The same with 「上限あり」 (P-B6 イ: at most `SpanPrototypeModel.cappedVisiblePages` weeks across).
        case landscapeCap = "landscape-cap"
        /// 「1 ページずつ」 (the old versions' view) on this week, the page that holds the crossing strokes'
        /// left halves.
        case singlePage = "single-page"
        /// 「1 ページずつ」 on the next week.
        case singlePageNext = "single-page-next"
        /// The first-time guide card over the band (it stays for the photo).
        case guide
        /// The week memo below 24:00 at the boundary, ruled lines only (§4.5, the default).
        case memoRuled = "memo-ruled"
        /// The same with the square grid.
        case memoGrid = "memo-grid"

        var weekStart: WeekStart {
            self == .sunday ? .sunday : .monday
        }

        /// The band opens with the boundary (this week's right edge) in the middle; false: this week's middle.
        var centersBoundary: Bool {
            self != .overview
        }

        var landscapeCap: Bool {
            self == .landscapeCap
        }

        var singlePage: Bool {
            self == .singlePage || self == .singlePageNext
        }

        /// The week 「1 ページずつ」 shows: this week (0) or the next (1).
        var pageOffset: Int {
            self == .singlePageNext ? 1 : 0
        }

        var memoStyle: SpanPrototypeMemoStyle {
            self == .memoGrid ? .grid : .ruled
        }

        var showsGuide: Bool {
            self == .guide
        }

        /// The band's first zoom (a ratio to the opening zoom) and the paper y (lu) at the top of the screen
        /// (nil: the top of the paper) for the window of `plan`.
        func opening(for plan: SpanPlan) -> (zoomRatio: CGFloat, topY: CGFloat?) {
            switch self {
            case .memoRuled, .memoGrid:
                // 18:00: the last six hours of the grid and the memo under them.
                return (1, SpanPrototypeShot.memoTopY)
            case .boundary where plan.deviceClass == .iPhone && plan.orientation == .landscape:
                // At the lowest zoom an iPhone in landscape shows about six weeks (the landscape scenes); here
                // the crossing strokes are shown twice as large, from 7:00.
                return (2, 7 * PaperSpec.weekHourHeight)
            default:
                return (1, nil)
            }
        }
    }

    /// This launch's scene: `--screenshot-prototype <scene>` together with `--screenshot-mode`; nil otherwise
    /// (an unknown scene too).
    static let current: Scene? = parse(ProcessInfo.processInfo.arguments)

    static func parse(_ arguments: [String]) -> Scene? {
        guard arguments.contains("--screenshot-mode"),
              let index = arguments.firstIndex(of: "--screenshot-prototype"), index + 1 < arguments.count else { return nil }
        return Scene(rawValue: arguments[index + 1])
    }

    /// The row has opened the prototype for this launch's scene (it does so once).
    @MainActor static var opened = false

    /// The paper y at the top of the memo scenes: 18:00.
    static let memoTopY: CGFloat = 18 * PaperSpec.weekHourHeight

    /// The scene's "now": screenshot mode's 「今日」 (10:00 on the 7th of `--screenshot-month`).
    @MainActor static var now: Date {
        ScreenshotMode.current?.today ?? Date()
    }

    /// The row waits for this before it opens the prototype: with `--screenshot-landscape` the root screen asks
    /// for landscape once it is active, and the band is opened for the size it gets (an iPhone turns within a
    /// moment; an iPad ignores the request, so after `limit` the prototype opens anyway).
    @MainActor
    static func waitForOrientation(limit: TimeInterval = 5) async {
        guard ScreenshotMode.current?.landscape == true else { return }
        let started = Date()
        while Date().timeIntervalSince(started) < limit, !Task.isCancelled {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            if scene?.effectiveGeometry.interfaceOrientation.isLandscape == true { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: The sample strokes

    /// One sample stroke, in the band lu of this week and the next (this week's origin 0, the boundary at
    /// `SpanPlan.pageWidth`); y is the cell's (`grid`: 0 = 0:00, 80 lu an hour; `extra`: 0 = 24:00, the memo).
    struct Sample {
        let id: String
        let cell: CellKey
        let color: String
        let nib: CGFloat
        let points: [CGPoint]
    }

    /// A fixed ms epoch; each sample gets its own `t`.
    static let baseTime = 1_791_100_000_000

    /// The samples: in the grid an arrow at 14:00 from the last day of this week into the first day of the next
    /// (its shaft held by this week, its head by the next), a line from the last night of this week to the first
    /// morning of the next (held by the next), a loop around the boundary at 9:00 (this week), and one short line
    /// inside each week; in the memo two lines across the boundary (one held by each week) and one line inside
    /// each week. Each is saved on the page under the centre x of its points' box (D15; the right one when the
    /// centre is on the boundary), its points relative to that page's cell.
    static let samples: [Sample] = {
        let hour = PaperSpec.weekHourHeight
        let w = PaperSpec.weekWidth
        let black = "#1f2937", blue = "#2563eb", red = "#dc2626"
        return [
            Sample(id: "sample-arrow", cell: .grid, color: black, nib: 7,
                   points: wave(from: CGPoint(x: w - 175, y: 14 * hour + 10), to: CGPoint(x: w + 160, y: 14 * hour - 10), count: 44, amplitude: 7)),
            Sample(id: "sample-arrow-head-1", cell: .grid, color: black, nib: 7,
                   points: line(from: CGPoint(x: w + 128, y: 14 * hour - 36), to: CGPoint(x: w + 162, y: 14 * hour - 10), count: 8)),
            Sample(id: "sample-arrow-head-2", cell: .grid, color: black, nib: 7,
                   points: line(from: CGPoint(x: w + 162, y: 14 * hour - 10), to: CGPoint(x: w + 130, y: 14 * hour + 18), count: 8)),
            Sample(id: "sample-night", cell: .grid, color: blue, nib: 7,
                   points: night(from: CGPoint(x: w - 100, y: 21 * hour + 10), to: CGPoint(x: w + 190, y: 3 * hour + 20), count: 48)),
            Sample(id: "sample-loop", cell: .grid, color: red, nib: 6,
                   points: loop(center: CGPoint(x: w - 8, y: 9 * hour + 20), radii: CGSize(width: 82, height: 46), count: 56)),
            Sample(id: "sample-note-left", cell: .grid, color: black, nib: 6,
                   points: wave(from: CGPoint(x: w - 360, y: 11 * hour), to: CGPoint(x: w - 220, y: 11 * hour), count: 24, amplitude: 6)),
            Sample(id: "sample-note-right", cell: .grid, color: black, nib: 6,
                   points: wave(from: CGPoint(x: w + 280, y: 18 * hour), to: CGPoint(x: w + 420, y: 18 * hour), count: 24, amplitude: 6)),
            Sample(id: "sample-memo-1", cell: .extra, color: black, nib: 7,
                   points: wave(from: CGPoint(x: w - 230, y: 160), to: CGPoint(x: w + 210, y: 170), count: 56, amplitude: 7)),
            Sample(id: "sample-memo-2", cell: .extra, color: blue, nib: 7,
                   points: wave(from: CGPoint(x: w - 150, y: 330), to: CGPoint(x: w + 320, y: 320), count: 58, amplitude: 7)),
            Sample(id: "sample-memo-left", cell: .extra, color: black, nib: 6,
                   points: wave(from: CGPoint(x: w - 640, y: 240), to: CGPoint(x: w - 300, y: 240), count: 40, amplitude: 6)),
            Sample(id: "sample-memo-right", cell: .extra, color: black, nib: 6,
                   points: wave(from: CGPoint(x: w + 360, y: 170), to: CGPoint(x: w + 750, y: 170), count: 44, amplitude: 6)),
        ]
    }()

    /// 0 when the centre x of the points' box is left of the boundary at `width`, else 1 (D15, half open).
    static func ownerSlot(of sample: Sample, width: CGFloat = PaperSpec.weekWidth) -> Int {
        let xs = sample.points.map(\.x)
        let center = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        return center < width ? 0 : 1
    }

    /// Writes the samples into the prototype's own store as the "proto-" pages of this week (the week of `today`)
    /// and the next, through the prototype's guard (§4.6 (a)), before a session reads them. The screenshot scenes
    /// only; a page the guard does not pass is left out (and logged).
    @MainActor
    static func seed(_ environment: SpanPrototypeEnvironment, weekStart: WeekStart, today: DayKey) {
        let plan = SpanPlan(kind: .week, weekStart: weekStart, deviceClass: .iPad11, orientation: .portrait)
        let left = plan.index(containing: today)
        var pages = [plan.pageId(at: left), plan.pageId(at: left + 1)].map { InkPage.empty(pageId: SpanPrototypeSession.fileId($0)) }
        var ids: [Set<String>] = [[], []]
        for (n, sample) in samples.enumerated() {
            let slot = ownerSlot(of: sample, width: plan.pageWidth)
            let dx = CGFloat(slot) * plan.pageWidth
            let points = sample.points.enumerated().map { index, point in
                InkPoint(x: point.x - dx, y: point.y, dtMs: index * 10, sizeW: sample.nib, sizeH: sample.nib, opacity: 1,
                         force: 0.5 + 0.15 * sin(CGFloat(index) * 0.3), azimuth: 0, altitude: 1.4)
            }
            pages[slot].add(InkStroke(id: sample.id, cell: sample.cell, tool: .pen, color: sample.color, t: baseTime + n * 1_000, points: points))
            ids[slot].insert(sample.id)
        }
        for (slot, page) in pages.enumerated() {
            guard case .ok = SpanGuard.checkForSave(page, added: ids[slot], mode: .prototype) else {
                log("seed: the guard did not pass \(page.pageId)")
                continue
            }
            do {
                try environment.store.save(page)
            } catch {
                log("seed: \(page.pageId) not saved: \(error)")
            }
        }
    }

    /// A line in DEBUG (the CI's app log): "span prototype shot: …".
    static func log(_ message: String) {
        #if DEBUG
        NSLog("span prototype shot: %@", message)
        #endif
    }

    // MARK: Shapes

    /// `count` points from `a` to `b` with a wave of `amplitude` across it (a written line).
    private static func wave(from a: CGPoint, to b: CGPoint, count: Int, amplitude: CGFloat) -> [CGPoint] {
        (0..<count).map { i in
            let f = CGFloat(i) / CGFloat(max(1, count - 1))
            return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f + amplitude * sin(CGFloat(i) * 0.55))
        }
    }

    /// `count` points on the straight line from `a` to `b`.
    private static func line(from a: CGPoint, to b: CGPoint, count: Int) -> [CGPoint] {
        (0..<count).map { i in
            let f = CGFloat(i) / CGFloat(max(1, count - 1))
            return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        }
    }

    /// From `a` to `b` bowed to the right of the straight line (a line written across the night).
    private static func night(from a: CGPoint, to b: CGPoint, count: Int) -> [CGPoint] {
        (0..<count).map { i in
            let f = CGFloat(i) / CGFloat(max(1, count - 1))
            return CGPoint(x: a.x + (b.x - a.x) * f + 70 * sin(f * .pi), y: a.y + (b.y - a.y) * f)
        }
    }

    /// A loop of 1.1 turns around `center`.
    private static func loop(center: CGPoint, radii: CGSize, count: Int) -> [CGPoint] {
        (0..<count).map { i in
            let angle = CGFloat(i) / CGFloat(max(1, count - 1)) * 2.2 * .pi - .pi / 2
            let grow = 1 + 0.08 * CGFloat(i) / CGFloat(max(1, count - 1))
            return CGPoint(x: center.x + radii.width * grow * cos(angle), y: center.y + radii.height * grow * sin(angle))
        }
    }
}
#endif
