import Holidays
import Layout
import ObjectiveC
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4 D0b probe (docs/M7D_CONTRACT.md; the quick branch r14-q-probe): why `PaperSpanTests.testTheOnePageBandIs1_2_3OnScreen`
/// finds 0 pixels of the bars' blue (#2563eb) for its two DAY cases (zoom 0.0854 width 874 offset -394, and 0.5 width 500
/// offset 0) on iOS 27.2 (24B8117) while its three week cases find them (D0 run 44632524223 and quick run 44649291195).
///
/// It renders the same bands the same way (a hosting controller in a window of the test host's scene, `drawHierarchy` at
/// 1 px per point; `renderOnScreen` copied from PaperSpanTests.swift:167-195) and, to tell the causes apart (the band
/// report's H1 status bar / scroll inset, H2 the all-square `UnevenRoundedRectangle`, H3 window lifecycle or order, H4
/// timing): the day cases first with a round one-day control (test1, the first method of the class), the test's own
/// order (test2), the window 300 pt down (test3), a 1 s wait and `CALayer.render(in:)` (test4), other bands (test5), a
/// bare bar square or round, alone or in a `ScrollView` 25 or 45 high (test6) and the day cases again last (test7).
/// Every render logs its number in the process, the UTC time with ms, the scene's activation state and window count,
/// the time of the layout, the wait and the draw, and what the picture holds (blue count and box, the paper colour, the
/// 8 most common colours); the hierarchy (scroll views' insets, offset, safe area and edge effects, edge / pocket /
/// blur views and the layers that draw) is dumped AFTER the picture. Lines start with `probe-band:`; the day pictures
/// also go into the log as base64 (`probe-band: png <label> i/n <chunk>`: the quick lane keeps no xcresult) and every
/// picture is attached (`keepAlways`).
///
/// It is a probe: it asserts nothing and cannot fail. The class name ends in `SpanTests` (the quick lane's filter) and
/// sorts after `PaperSpanTests` (XCTest runs classes and methods in name order), so the real test stays a clean repeat
/// of D0 and this class's renders come after its 15 windows.
@MainActor
final class ProbeBandSpanTests: XCTestCase {
    /// PaperSpanTests' day: 2026-11-11, a Wednesday, 10:00.
    private let today = DayKey(year: 2026, month: 11, day: 11)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }

    /// Renders made by this class in this process, over all its tests (their order in the run).
    private static var renders = 0
    /// Pictures still to go into the log as base64.
    private static var base64Left = 16
    private var lines: [String] = []

    override func tearDown() async throws {
        let all = XCTAttachment(string: lines.joined(separator: "\n"))
        all.name = "probe-band-\(name).txt"
        all.lifetime = .keepAlways
        add(all)
    }

    // MARK: - Logging

    private static let clockFormat: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(identifier: "UTC")
        format.dateFormat = "HH:mm:ss.SSS"
        return format
    }()

    private static func clock() -> String { clockFormat.string(from: Date()) }

    /// One `probe-band:` line (cut into pieces of 900 characters: NSLog may shorten a longer one).
    private func log(_ text: String) {
        lines.append(text)
        let limit = 900
        guard text.count > limit else {
            NSLog("probe-band: %@", text)
            return
        }
        let pieces = stride(from: 0, to: text.count, by: limit).map { start -> String in
            let from = text.index(text.startIndex, offsetBy: start)
            let to = text.index(from, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[from..<to])
        }
        for (index, piece) in pieces.enumerated() {
            NSLog("probe-band: [%d/%d] %@", index + 1, pieces.count, piece)
        }
    }

    private static func f(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
    private static func r(_ rect: CGRect) -> String { "(\(f(rect.minX)), \(f(rect.minY)), \(f(rect.width))x\(f(rect.height)))" }
    private static func i(_ e: UIEdgeInsets) -> String { "t\(f(e.top)) l\(f(e.left)) b\(f(e.bottom)) r\(f(e.right))" }
    private static func ms(_ seconds: TimeInterval) -> String { String(format: "%.1f", seconds * 1000) }

    private static func hex(_ color: CGColor?) -> String {
        guard let color = color else { return "nil" }
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap { color.converted(to: $0, intent: .defaultIntent, options: nil) } ?? color
        let c = srgb.components ?? []
        guard c.count >= 3 else { return "gray\(c.map { f($0) })" }
        let a = c.count >= 4 ? c[3] : 1
        return String(format: "#%02x%02x%02x a%.3f", Int((c[0] * 255).rounded()), Int((c[1] * 255).rounded()), Int((c[2] * 255).rounded()), Double(a))
    }

    private static func state(_ scene: UIScene?) -> String {
        guard let scene = scene else { return "no-scene" }
        switch scene.activationState {
        case .unattached: return "unattached"
        case .foregroundActive: return "foregroundActive"
        case .foregroundInactive: return "foregroundInactive"
        case .background: return "background"
        @unknown default: return "state\(scene.activationState.rawValue)"
        }
    }

    private static var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private func logEnvironment(_ test: String) {
        let scene = Self.windowScene
        let screen = scene.map { "\(Self.r($0.screen.bounds)) scale \(Self.f($0.screen.scale))" } ?? "no scene"
        let orientation = scene.map { "\($0.effectiveGeometry.interfaceOrientation.rawValue)" } ?? "-"
        log("\(test): env \(Self.clock()) iOS \(UIDevice.current.systemVersion) \(UIDevice.current.model) idiom \(UIDevice.current.userInterfaceIdiom.rawValue) screen \(screen) orientation \(orientation) scenes \(UIApplication.shared.connectedScenes.count) scene=\(Self.state(scene)) windows \(scene?.windows.count ?? -1) statusBar \(Self.r(scene?.statusBarManager?.statusBarFrame ?? .zero)) language \(L.language) rendersSoFar \(Self.renders)")
    }

    // MARK: - Pages and events (PaperSpanTests' helpers, copied from PaperSpanTests.swift:56-78: theirs are private)

    private func week(_ first: DayKey, events: [LayoutEvent]) -> PaperContent {
        .week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: events, inkBottoms: [:], now: now))))
    }

    private func day(_ day: DayKey, events: [LayoutEvent]) -> PaperContent {
        .day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: day, events: events, inkBottoms: [:], now: now))))
    }

    private func allDay(_ id: String, from first: DayKey, days: Int) -> LayoutEvent {
        LayoutEvent(id: id, title: id, allDay: true, start: first.startOfDay(in: DayKey.deviceCalendar),
                    end: first.adding(days: days).startOfDay(in: DayKey.deviceCalendar), colorHex: "#2563eb", calendarId: "c")
    }

    // MARK: - The cases

    private struct Case {
        var name: String
        var band: AllDayBandLayout
        var paper: PaperContent
        var zoom: CGFloat
        var laneZoom: CGFloat?
        var width: CGFloat
        var offsetX: CGFloat
        var viewport: PaperViewport { PaperViewport(offsetX: offsetX, zoom: zoom, width: width) }
    }

    private var first: DayKey { DayKey(year: 2026, month: 11, day: 9) }

    /// PaperSpanTests.swift:673-692: its events (from-before, to-after, middle).
    private var events: [LayoutEvent] {
        [allDay("from-before", from: DayKey(year: 2026, month: 11, day: 6), days: 5),
         allDay("to-after", from: DayKey(year: 2026, month: 11, day: 14), days: 4),
         allDay("middle", from: DayKey(year: 2026, month: 11, day: 10), days: 3)]
    }

    /// The test's five cases, in its order (0–2 week, 3–4 day).
    private func testCases() -> [Case] {
        let weekPaper = week(first, events: events)
        let dayPaper = day(today, events: events)
        let weekBand = AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: events, now: now, holidays: .japan)
        let dayBand = AllDayBandEngine.day(today, events: events, now: now, holidays: .japan)
        return [
            Case(name: "week-0.1068", band: weekBand, paper: weekPaper, zoom: 0.1068, laneZoom: nil, width: 874, offsetX: -((874 - 1400 * 0.1068) / 2).rounded()),
            Case(name: "week-0.5", band: weekBand, paper: weekPaper, zoom: 0.5, laneZoom: nil, width: 700, offsetX: 0),
            Case(name: "week-0.5-lane0.3", band: weekBand, paper: weekPaper, zoom: 0.5, laneZoom: 0.3, width: 600, offsetX: 120),
            Case(name: "day-0.0854", band: dayBand, paper: dayPaper, zoom: 0.0854, laneZoom: nil, width: 874, offsetX: -((874 - 1000 * 0.0854) / 2).rounded()),
            Case(name: "day-0.5", band: dayBand, paper: dayPaper, zoom: 0.5, laneZoom: nil, width: 500, offsetX: 0),
        ]
    }

    /// Other bands: a one-day event on the day (round on both sides, as the D0 photos' 締切), two lanes on the day
    /// (the square bar on lane 0, a round one on lane 1), and a week bar square on both sides (an event over the week).
    private func otherCases() -> [Case] {
        let oneDay = [allDay("one-day", from: today, days: 1)]
        let twoLanes = [events[2], allDay("one-day", from: today, days: 1)]
        let longWeek = [allDay("long", from: DayKey(year: 2026, month: 11, day: 2), days: 21)]
        return [
            Case(name: "day-oneDay-0.5", band: AllDayBandEngine.day(today, events: oneDay, now: now, holidays: .japan), paper: day(today, events: oneDay),
                 zoom: 0.5, laneZoom: nil, width: 500, offsetX: 0),
            Case(name: "day-oneDay-0.0854", band: AllDayBandEngine.day(today, events: oneDay, now: now, holidays: .japan), paper: day(today, events: oneDay),
                 zoom: 0.0854, laneZoom: nil, width: 874, offsetX: -((874 - 1000 * 0.0854) / 2).rounded()),
            Case(name: "day-twoLanes-0.5", band: AllDayBandEngine.day(today, events: twoLanes, now: now, holidays: .japan), paper: day(today, events: twoLanes),
                 zoom: 0.5, laneZoom: nil, width: 500, offsetX: 0),
            Case(name: "week-squareBoth-0.5", band: AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: longWeek, now: now, holidays: .japan),
                 paper: week(first, events: longWeek), zoom: 0.5, laneZoom: nil, width: 700, offsetX: 0),
        ]
    }

    private func frozen(_ c: Case) -> Frozen123AllDayBand {
        Frozen123AllDayBand(band: c.band, viewport: c.viewport, pageHeight: 400, laneZoom: c.laneZoom)
    }

    private func plain(_ c: Case) -> AllDayBandView {
        AllDayBandView(band: c.band, viewport: c.viewport, pageHeight: 400, laneZoom: c.laneZoom, onBarTap: { _ in }, onColumnTap: { _ in })
    }

    private static let height: CGFloat = 120

    // MARK: - Pictures

    /// PaperSpanTests' Bitmap (copied from PaperSpanTests.swift:92-99 and :130-143; its `pixel`), with the counts
    /// this probe needs.
    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// PaperSpanTests' test (PaperSpanTests.swift:709-714): within 12 of #2563eb in every channel.
        static func isBlue(_ p: (r: Int, g: Int, b: Int)) -> Bool {
            abs(p.r - 0x25) <= 12 && abs(p.g - 0x63) <= 12 && abs(p.b - 0xeb) <= 12
        }

        /// The paper #fffdf8, within 3.
        static func isPaper(_ p: (r: Int, g: Int, b: Int)) -> Bool {
            abs(p.r - 0xff) <= 3 && abs(p.g - 0xfd) <= 3 && abs(p.b - 0xf8) <= 3
        }

        func differences(_ other: Bitmap) -> Int {
            guard other.width == width, other.height == height else { return -1 }
            var count = 0
            for y in 0..<height {
                for x in 0..<width {
                    let p = pixel(x, y)
                    let q = other.pixel(x, y)
                    if p.r != q.r || p.g != q.g || p.b != q.b { count += 1 }
                }
            }
            return count
        }

        static func of(_ cg: CGImage?) -> Bitmap {
            guard let cg = cg else { return Bitmap(bytes: [], width: 0, height: 0) }
            let width = cg.width
            let height = cg.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            bytes.withUnsafeMutableBytes { buffer in
                guard let ctx = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            return Bitmap(bytes: bytes, width: width, height: height)
        }
    }

    private struct Shot {
        var label: String
        var image: UIImage?
        var bitmap: Bitmap
        var drew: Bool
    }

    /// How a picture is taken: PaperSpanTests' `renderOnScreen` is `windowY 0, wait 0.05, layerRender false`.
    private struct Way {
        var windowY: CGFloat = 0
        var wait: TimeInterval = 0.05
        /// `host.view.layer.render(in:)` instead of `drawHierarchy` (the app's layer tree, not the render server).
        var layerRender = false
        /// Log the hierarchy after the picture, before the window goes.
        var dump = false
    }

    /// PaperSpanTests' `renderOnScreen` (copied from PaperSpanTests.swift:167-195) with the window's y, the wait and the
    /// drawing call as parameters, timed and logged; the hierarchy is dumped after the picture.
    private func renderOnScreen<V: View>(_ label: String, _ view: V, size: CGSize, _ way: Way = Way()) -> Shot {
        Self.renders += 1
        let number = Self.renders
        guard let scene = Self.windowScene else {
            log("#\(number) \(label): no window scene")
            return Shot(label: label, image: nil, bitmap: Bitmap(bytes: [], width: 0, height: 0), drew: false)
        }
        let startClock = Self.clock()
        let stateBefore = Self.state(scene)
        let windowsBefore = scene.windows.count
        let t0 = Date()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: CGPoint(x: 0, y: way.windowY), size: size)
        let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading).ignoresSafeArea())
        host.safeAreaRegions = []
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let t1 = Date()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: way.wait))
        host.view.layoutIfNeeded()
        let t2 = Date()
        let windowsShown = scene.windows.count
        let stateShown = Self.state(scene)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        var drew = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            if way.layerRender {
                host.view.layer.render(in: context.cgContext)
            } else {
                drew = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
        }
        let t3 = Date()
        log("#\(number) \(label): start \(startClock) end \(Self.clock()) windowY \(Self.f(way.windowY)) wait \(way.wait) \(way.layerRender ? "layer.render(in:)" : "drawHierarchy") drew=\(drew) scene=\(stateBefore)->\(stateShown) windows \(windowsBefore)->\(windowsShown) key=\(window.isKeyWindow) windowSafe \(Self.i(window.safeAreaInsets)) hostSafe \(Self.i(host.view.safeAreaInsets)) layout \(Self.ms(t1.timeIntervalSince(t0))) ms waited \(Self.ms(t2.timeIntervalSince(t1))) ms draw \(Self.ms(t3.timeIntervalSince(t2))) ms total \(Self.ms(t3.timeIntervalSince(t0))) ms")
        if way.dump {
            dumpHierarchy("#\(number) \(label)", window: window, host: host)
        }
        return Shot(label: label, image: image, bitmap: Bitmap.of(image.cgImage), drew: drew)
    }

    // MARK: - What a picture holds

    /// One line: size, blue / paper / white / black counts, the blue's box and the 8 most common colours.
    @discardableResult
    private func summarize(_ shot: Shot, rows: Bool = false) -> Int {
        let b = shot.bitmap
        var blue = 0, paper = 0, white = 0, black = 0
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        var histogram: [UInt32: Int] = [:]
        for y in 0..<b.height {
            for x in 0..<b.width {
                let p = b.pixel(x, y)
                if Bitmap.isBlue(p) {
                    blue += 1
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
                if Bitmap.isPaper(p) { paper += 1 }
                if p.r == 255, p.g == 255, p.b == 255 { white += 1 }
                if p.r < 8, p.g < 8, p.b < 8 { black += 1 }
                histogram[UInt32(p.r) << 16 | UInt32(p.g) << 8 | UInt32(p.b), default: 0] += 1
            }
        }
        let top = histogram.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(8)
            .map { String(format: "#%06x:%d", $0.key, $0.value) }.joined(separator: " ")
        let box = blue > 0 ? "x\(minX)...\(maxX) y\(minY)...\(maxY)" : "-"
        log("\(shot.label): size \(b.width)x\(b.height) blue=\(blue) box=\(box) paper=\(paper) white=\(white) black=\(black) colours=\(histogram.count) top=[\(top)]")
        if rows {
            logRows(shot)
        }
        return blue
    }

    /// The first 60 rows, runs of equal rows together: blue (and its x range), paper, white, other, and the first /
    /// last x that is not white.
    private func logRows(_ shot: Shot) {
        let b = shot.bitmap
        var previous = ""
        var start = 0
        func flush(_ end: Int) {
            guard !previous.isEmpty else { return }
            log("\(shot.label): rows \(start)...\(end) \(previous)")
        }
        for y in 0..<min(b.height, 60) {
            var blue = 0, paper = 0, white = 0, other = 0
            var bx0 = Int.max, bx1 = -1, nx0 = Int.max, nx1 = -1
            for x in 0..<b.width {
                let p = b.pixel(x, y)
                if Bitmap.isBlue(p) {
                    blue += 1; bx0 = min(bx0, x); bx1 = max(bx1, x)
                } else if Bitmap.isPaper(p) {
                    paper += 1
                } else if p.r == 255, p.g == 255, p.b == 255 {
                    white += 1
                } else {
                    other += 1
                }
                if !(p.r == 255 && p.g == 255 && p.b == 255) { nx0 = min(nx0, x); nx1 = max(nx1, x) }
            }
            let signature = "blue=\(blue)\(blue > 0 ? "[\(bx0)...\(bx1)]" : "") paper=\(paper) white=\(white) other=\(other) nonwhite=\(nx1 >= 0 ? "\(nx0)...\(nx1)" : "-")"
            if signature != previous {
                flush(y - 1)
                previous = signature
                start = y
            }
        }
        flush(min(b.height, 60) - 1)
    }

    /// `XCTAttachment(data:uniformTypeIdentifier:)` through its Objective-C class method, so that the local type check's
    /// XCTest stand-in (tools/typecheck/XCTestStandIn.swift: only `init(string:)` and `init(screenshot:)`) needs no change.
    private static func attachment(_ data: Data, uniformTypeIdentifier: String) -> XCTAttachment? {
        let selector = NSSelectorFromString("attachmentWithData:uniformTypeIdentifier:")
        guard let type = (XCTAttachment.self as AnyObject) as? NSObjectProtocol, type.responds(to: selector) else { return nil }
        return type.perform(selector, with: data as NSData, with: uniformTypeIdentifier as NSString)?.takeUnretainedValue() as? XCTAttachment
    }

    /// The PNG as an attachment, and (while the budget lasts) in the log as base64 in chunks of 800 characters.
    private func keep(_ shot: Shot, base64: Bool = false) {
        guard let png = shot.image?.pngData() else {
            log("\(shot.label): no PNG")
            return
        }
        if let attachment = Self.attachment(png, uniformTypeIdentifier: "public.png") {
            attachment.name = "probe-band-\(shot.label).png"
            attachment.lifetime = .keepAlways
            add(attachment)
        } else {
            log("\(shot.label): XCTAttachment(data:uniformTypeIdentifier:) unavailable; PNG not attached")
        }
        guard base64, Self.base64Left > 0 else { return }
        Self.base64Left -= 1
        let text = png.base64EncodedString()
        let chunk = 800
        let count = (text.count + chunk - 1) / chunk
        var index = text.startIndex
        var n = 1
        while index < text.endIndex {
            let end = text.index(index, offsetBy: chunk, limitedBy: text.endIndex) ?? text.endIndex
            log("png \(shot.label) \(n)/\(count) \(text[index..<end])")
            index = end
            n += 1
        }
    }

    /// The rectangles `AllDayBandView` lays out for the case (container points): the band, each column and its tint,
    /// the gutter and each bar with its corner radii (0 on a side that continues).
    private func logLayout(_ label: String, _ c: Case) {
        let band = c.band
        let viewport = c.viewport
        let m = AllDayBandMetrics.metrics(kind: band.kind, laneCount: band.laneCount, zoom: c.laneZoom ?? viewport.zoom, pageHeight: 400)
        log("\(label): layout kind=\(band.kind) lanes=\(band.laneCount) lane=\(Self.f(m.lane)) gap=\(Self.f(m.gap)) text=\(Self.f(m.text)) content=\(Self.f(m.contentHeight)) visible=\(Self.f(m.visibleHeight)) scrollsInside=\(m.scrollsInside) band=(0, 0, \(Self.f(viewport.width))x\(Self.f(m.visibleHeight))) today=\(band.todayColumn.map(String.init) ?? "nil") tones=\(band.tones)")
        for (index, minX) in band.columnMinX.enumerated() {
            let x = viewport.x(ofPaper: minX)
            let w = viewport.width(ofPaper: band.columnWidth)
            let tint = band.todayColumn == index ? (band.kind == .day ? "todayTintSoft" : "todayTint")
                : (index < band.tones.count && band.tones[index] != .normal ? (band.kind == .day ? "weekendTintSoft" : "weekendTint") : "none")
            log("\(label): column \(index) \(Self.r(CGRect(x: x, y: 0, width: w, height: m.contentHeight))) tint=\(tint)")
        }
        log("\(label): gutter \(Self.r(CGRect(x: viewport.x(ofPaper: 0), y: m.laneTop(0), width: viewport.width(ofPaper: band.gutter), height: m.lane)))")
        for bar in band.bars {
            let rect = CGRect(x: viewport.x(ofPaper: bar.minX), y: m.laneTop(bar.lane), width: max(0, viewport.width(ofPaper: bar.maxX - bar.minX)), height: m.lane)
            let left = bar.continuesLeft ? 0 : AllDayBandView.barCorner
            let right = bar.continuesRight ? 0 : AllDayBandView.barCorner
            log("\(label): bar \(bar.eventId) lane \(bar.lane) cols \(bar.startCol)...\(bar.endCol) paper x \(Self.f(bar.minX))...\(Self.f(bar.maxX)) rect \(Self.r(rect)) radii left \(Self.f(left)) right \(Self.f(right)) colour \(bar.colorHex)")
        }
    }

    // MARK: - The hierarchy (after the picture)

    private static func edgeEffects(_ scroll: UIScrollView) -> String {
        if #available(iOS 26.0, *) {
            func one(_ side: String, _ effect: UIScrollEdgeEffect) -> String {
                let style: String
                if effect.style === UIScrollEdgeEffect.Style.automatic {
                    style = "automatic"
                } else if effect.style === UIScrollEdgeEffect.Style.soft {
                    style = "soft"
                } else if effect.style === UIScrollEdgeEffect.Style.hard {
                    style = "hard"
                } else {
                    style = String(describing: effect.style)
                }
                return "\(side)(hidden=\(effect.isHidden) \(style))"
            }
            return [one("top", scroll.topEdgeEffect), one("left", scroll.leftEdgeEffect), one("bottom", scroll.bottomEdgeEffect),
                    one("right", scroll.rightEdgeEffect)].joined(separator: " ")
        }
        return "edge effects: none before iOS 26"
    }

    /// By reflection (metadata only, nothing is called): the properties and methods of the scroll view's classes up to
    /// UIScrollView whose names hold "edge", "pocket" or "inset".
    private static func reflectedEdgeNames(_ object: AnyObject) -> String {
        var found: [String] = []
        var current: AnyClass? = object_getClass(object)
        while let cls = current {
            let className = NSStringFromClass(cls)
            var count: UInt32 = 0
            if let list = class_copyPropertyList(cls, &count) {
                for index in 0..<Int(count) {
                    let name = String(cString: property_getName(list[index]))
                    let lower = name.lowercased()
                    if lower.contains("edge") || lower.contains("pocket") || lower.contains("inset") { found.append("\(className).\(name)") }
                }
                free(list)
            }
            var methodCount: UInt32 = 0
            if let methods = class_copyMethodList(cls, &methodCount) {
                for index in 0..<Int(methodCount) {
                    let name = NSStringFromSelector(method_getName(methods[index]))
                    let lower = name.lowercased()
                    if lower.contains("edgeeffect") || lower.contains("pocket") { found.append("\(className)-\(name)") }
                }
                free(methods)
            }
            if ObjectIdentifier(cls) == ObjectIdentifier(UIScrollView.self) { break }
            current = class_getSuperclass(cls)
        }
        let shown = found.prefix(60).joined(separator: " ")
        return found.count > 60 ? "\(shown) …(\(found.count))" : shown
    }

    private static func matchesEffect(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["edge", "pocket", "blur", "backdrop", "fade", "gradient", "effect", "shadow", "portal", "mask"].contains { lower.contains($0) }
    }

    /// The window, its scene, every scroll view (insets, offset, safe area, edge effects and the edge / pocket names
    /// its classes have), the views whose class names say edge / pocket / blur / backdrop / fade / gradient / effect,
    /// and the layers that draw something (frame in the window, background, corners, clipping, filters), at most 50.
    private func dumpHierarchy(_ label: String, window: UIWindow, host: UIViewController) {
        let scene = window.windowScene
        log("\(label): dump at \(Self.clock()): window \(Self.r(window.frame)) level \(Self.f(window.windowLevel.rawValue)) safe \(Self.i(window.safeAreaInsets)) host.view \(Self.r(host.view.frame)) safe \(Self.i(host.view.safeAreaInsets)) additional \(Self.i(host.additionalSafeAreaInsets)) statusBar \(Self.r(scene?.statusBarManager?.statusBarFrame ?? .zero)) scene=\(Self.state(scene)) windows \(scene?.windows.count ?? -1) sceneBounds \(scene.map { Self.r($0.coordinateSpace.bounds) } ?? "-")")
        var views: [UIView] = [window]
        var all = 0
        var scrolls = 0
        while let view = views.popLast() {
            all += 1
            views.append(contentsOf: view.subviews.reversed())
            let typeName = NSStringFromClass(type(of: view))
            if let scroll = view as? UIScrollView {
                scrolls += 1
                log("\(label): scroll \(typeName) inWindow \(Self.r(scroll.convert(scroll.bounds, to: window))) bounds \(Self.r(scroll.bounds)) offset (\(Self.f(scroll.contentOffset.x)), \(Self.f(scroll.contentOffset.y))) size \(Self.f(scroll.contentSize.width))x\(Self.f(scroll.contentSize.height)) contentInset \(Self.i(scroll.contentInset)) adjusted \(Self.i(scroll.adjustedContentInset)) safe \(Self.i(scroll.safeAreaInsets)) indicatorInsets \(Self.i(scroll.verticalScrollIndicatorInsets)) behavior \(scroll.contentInsetAdjustmentBehavior.rawValue) clips=\(scroll.clipsToBounds) hidden=\(scroll.isHidden) alpha=\(Self.f(scroll.alpha)) scrollEnabled=\(scroll.isScrollEnabled) \(Self.edgeEffects(scroll))")
                log("\(label): scroll \(typeName) reflected: \(Self.reflectedEdgeNames(scroll))")
            } else if Self.matchesEffect(typeName) {
                log("\(label): view \(typeName) inWindow \(Self.r(view.convert(view.bounds, to: window))) hidden=\(view.isHidden) alpha=\(Self.f(view.alpha)) clips=\(view.clipsToBounds)")
            }
        }
        log("\(label): views \(all), scroll views \(scrolls)")
        var count = 0
        var skipped = 0
        func walk(_ layer: CALayer, _ depth: Int) {
            let typeName = NSStringFromClass(type(of: layer))
            let filters = (layer.value(forKey: "filters") as? [Any])?.count ?? 0
            let backgroundFilters = (layer.value(forKey: "backgroundFilters") as? [Any])?.count ?? 0
            let compositing = layer.value(forKey: "compositingFilter").map { String(describing: $0) } ?? "nil"
            let draws = (layer.backgroundColor.map { $0.alpha > 0 } ?? false) || layer.masksToBounds || layer.mask != nil || layer.contents != nil
                || layer.isHidden || filters > 0 || backgroundFilters > 0 || compositing != "nil" || Self.matchesEffect(typeName)
            if draws {
                if count < 50 {
                    count += 1
                    let frame = layer.convert(layer.bounds, to: window.layer)
                    let owner = (layer.delegate as? UIView).map { " view \(NSStringFromClass(type(of: $0)))" } ?? ""
                    log("\(label): layer \(depth) \(typeName)\(owner) inWindow \(Self.r(frame)) bg \(Self.hex(layer.backgroundColor)) opacity \(Self.f(CGFloat(layer.opacity))) hidden=\(layer.isHidden) radius \(Self.f(layer.cornerRadius)) curve \(layer.cornerCurve.rawValue) corners \(layer.maskedCorners.rawValue) clips=\(layer.masksToBounds) mask=\(layer.mask.map { NSStringFromClass(type(of: $0)) } ?? "nil") contents=\(layer.contents != nil) filters=\(filters) backgroundFilters=\(backgroundFilters) compositing=\(compositing)")
                } else {
                    skipped += 1
                }
            }
            for sublayer in layer.sublayers ?? [] {
                walk(sublayer, depth + 1)
            }
        }
        walk(window.layer, 0)
        if skipped > 0 { log("\(label): \(skipped) more layer lines left out") }
    }

    // MARK: - A bare bar (no app code): AllDayBandView's bar, alone or in the band's ScrollView

    private enum BarShape {
        case uneven(left: CGFloat, right: CGFloat)
        case rectangle
    }

    private struct ReplicaBar: View {
        var shape: BarShape
        var inScroll: Bool
        var width: CGFloat
        var height: CGFloat

        var body: some View {
            if inScroll {
                ScrollView(.vertical, showsIndicators: true) {
                    content.frame(width: width, height: height, alignment: .topLeading)
                }
                .scrollDisabled(true)
                .frame(width: width, height: height)
                .background(Color(uiColor: PaperPalette.paper))
                .clipped()
            } else {
                content
                    .frame(width: width, height: height, alignment: .topLeading)
                    .background(Color(uiColor: PaperPalette.paper))
            }
        }

        @ViewBuilder
        private var bar: some View {
            let label = Text("middle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(width: 286, height: 18, alignment: .leading)
            let fill = Color(uiColor: PaperPalette.color(hex: "#2563eb"))
            switch shape {
            case .uneven(let left, let right):
                let uneven = UnevenRoundedRectangle(topLeadingRadius: left, bottomLeadingRadius: left, bottomTrailingRadius: right, topTrailingRadius: right)
                label.background(uneven.fill(fill)).clipShape(uneven).contentShape(Rectangle())
            case .rectangle:
                label.background(Rectangle().fill(fill)).clipShape(Rectangle()).contentShape(Rectangle())
            }
        }

        private var content: some View {
            ZStack(alignment: .topLeading) {
                Button {} label: { bar }
                    .buttonStyle(.plain)
                    .offset(x: 38, y: 3)
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
    }

    // MARK: - The probes (XCTest runs them in name order)

    /// First in the class: the two day cases before anything else of this class, then a round one-day bar on the day
    /// (control) and a week case (control), all as the test draws them (frozen band, window at y 0, 0.05 s).
    func test1DayFirst() {
        logEnvironment("T1")
        let cases = testCases()
        let controls = otherCases()
        let order: [(Case, Bool)] = [(cases[3], true), (cases[4], true), (controls[0], false), (cases[1], false)]
        for (c, isDay) in order {
            logLayout("T1-\(c.name)", c)
            let shot = renderOnScreen("T1-first-\(c.name)", frozen(c), size: CGSize(width: c.width, height: Self.height), Way(dump: isDay))
            summarize(shot, rows: true)
            keep(shot, base64: true)
        }
        log("T1: done at \(Self.clock())")
    }

    /// The test's own sequence: its five cases in its order, each drawn frozen, plain and in a window of one page; the
    /// hierarchy after the frozen picture.
    func test2AsTheTestDoesIt() {
        logEnvironment("T2")
        let dayPaper = day(today, events: events)
        let dayBand = AllDayBandEngine.day(today, events: events, now: now, holidays: .japan)
        log("T2: bands: day == paper's \(dayPaper.allDayBand == dayBand)")
        for c in testCases() {
            let label = "T2-\(c.name)"
            logLayout(label, c)
            let size = CGSize(width: c.width, height: Self.height)
            let frozenShot = renderOnScreen("\(label)-frozen", frozen(c), size: size, Way(dump: true))
            let plainShot = renderOnScreen("\(label)-plain", plain(c), size: size)
            var windowedShot: Shot?
            if let single = PaperSpan.single(c.paper) {
                let windowed = AllDayBandView(band: single.bands[0], viewport: c.viewport, pageHeight: 400, laneZoom: c.laneZoom, span: single,
                                              onBarTap: { _ in }, onColumnTap: { _ in })
                windowedShot = renderOnScreen("\(label)-windowed", windowed, size: size)
            } else {
                log("\(label): PaperSpan.single gave nil")
            }
            summarize(frozenShot, rows: c.band.kind == .day)
            keep(frozenShot, base64: c.band.kind == .day)
            summarize(plainShot)
            keep(plainShot)
            if let windowedShot = windowedShot {
                summarize(windowedShot)
                keep(windowedShot)
                log("\(label): differing pixels plain/frozen \(plainShot.bitmap.differences(frozenShot.bitmap)) windowed/frozen \(windowedShot.bitmap.differences(frozenShot.bitmap))")
            }
        }
        log("T2: done at \(Self.clock())")
    }

    /// The window 300 pt down (under no status bar or other safe area), the test's five cases, frozen.
    func test3TheWindow300PointsDown() {
        logEnvironment("T3")
        for c in testCases() {
            let isDay = c.band.kind == .day
            let shot = renderOnScreen("T3-y300-\(c.name)", frozen(c), size: CGSize(width: c.width, height: Self.height), Way(windowY: 300, dump: isDay))
            summarize(shot, rows: isDay)
            keep(shot, base64: isDay)
        }
        log("T3: done at \(Self.clock())")
    }

    /// 0.05 s against 1 s before the picture (the day cases and the round control), then `layer.render(in:)`.
    func test4WaitsAndLayerRender() {
        logEnvironment("T4")
        let cases = testCases()
        let controls = otherCases()
        for c in [cases[3], cases[4], controls[0]] {
            let size = CGSize(width: c.width, height: Self.height)
            let short = renderOnScreen("T4-wait0.05-\(c.name)", frozen(c), size: size, Way(wait: 0.05))
            summarize(short)
            keep(short)
            let long = renderOnScreen("T4-wait1-\(c.name)", frozen(c), size: size, Way(wait: 1))
            summarize(long, rows: c.band.kind == .day && c.name != controls[0].name)
            keep(long, base64: c.name != controls[0].name)
        }
        for c in [cases[3], cases[4]] {
            let layers = renderOnScreen("T4-layerRender-\(c.name)", frozen(c), size: CGSize(width: c.width, height: Self.height), Way(layerRender: true))
            summarize(layers, rows: true)
            keep(layers)
        }
        log("T4: done at \(Self.clock())")
    }

    /// Other bands with the app's view, at y 0 and y 300: a one-day bar on the day (round), two lanes on the day and a
    /// week bar square on both sides.
    func test5OtherBands() {
        logEnvironment("T5")
        for c in otherCases() {
            logLayout("T5-\(c.name)", c)
            for y: CGFloat in [0, 300] {
                let shot = renderOnScreen("T5-y\(Int(y))-\(c.name)", plain(c), size: CGSize(width: c.width, height: Self.height), Way(windowY: y))
                summarize(shot, rows: true)
                keep(shot)
            }
        }
        log("T5: done at \(Self.clock())")
    }

    /// A bare bar at (38, 3) 286 × 18 on the paper colour, 500 wide: an all-square `UnevenRoundedRectangle` against a
    /// round one (radii 4), alone or in a ScrollView, the content 25 or 45 high, and a plain `Rectangle` in the 25-pt
    /// ScrollView; each at y 0 and y 300.
    func test6BareBars() {
        logEnvironment("T6")
        let replicas: [(name: String, shape: BarShape, inScroll: Bool, height: CGFloat)] = [
            ("square-plain-25", .uneven(left: 0, right: 0), false, 25),
            ("round-plain-25", .uneven(left: 4, right: 4), false, 25),
            ("square-scroll-25", .uneven(left: 0, right: 0), true, 25),
            ("round-scroll-25", .uneven(left: 4, right: 4), true, 25),
            ("square-plain-45", .uneven(left: 0, right: 0), false, 45),
            ("round-plain-45", .uneven(left: 4, right: 4), false, 45),
            ("square-scroll-45", .uneven(left: 0, right: 0), true, 45),
            ("round-scroll-45", .uneven(left: 4, right: 4), true, 45),
            ("rect-scroll-25", .rectangle, true, 25),
        ]
        for replica in replicas {
            for y: CGFloat in [0, 300] {
                let view = ReplicaBar(shape: replica.shape, inScroll: replica.inScroll, width: 500, height: replica.height)
                let firstOfKind = y == 0 && replica.inScroll && replica.height == 25 && replica.name != "rect-scroll-25"
                let shot = renderOnScreen("T6-y\(Int(y))-\(replica.name)", view, size: CGSize(width: 500, height: Self.height),
                                          Way(windowY: y, dump: y == 0 && replica.inScroll && replica.name.hasPrefix("square")))
                summarize(shot, rows: true)
                keep(shot, base64: firstOfKind)
            }
        }
        log("T6: done at \(Self.clock())")
    }

    /// Last in the class: test1's renders again (do the controls still draw after this class's other renders?).
    func test7DayAgainAtTheEnd() {
        logEnvironment("T7")
        let cases = testCases()
        let controls = otherCases()
        for (c, isDay) in [(cases[3], true), (cases[4], true), (controls[0], false), (cases[1], false)] {
            let shot = renderOnScreen("T7-last-\(c.name)", frozen(c), size: CGSize(width: c.width, height: Self.height), Way(dump: isDay))
            summarize(shot, rows: isDay)
            keep(shot, base64: isDay)
        }
        log("T7: done at \(Self.clock()); renders by this class \(Self.renders)")
    }
}
