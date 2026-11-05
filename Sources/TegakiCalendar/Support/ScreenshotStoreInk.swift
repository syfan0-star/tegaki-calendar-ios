import CoreGraphics
import Foundation
import InkModel
import Layout

/// The handwriting of the App Store's photos (`--screenshot-store-ink`, docs/M7B.md FIX4): what a person
/// writes on a calendar, so the listing shows a handwriting app. Only `store-shots.yml` passes the argument;
/// the demo pages of everything else (the fixtures of K-7, the Japanese photos of J-4) do not come here.
///
/// The same in every language (like the demo ink, K-7): what could be read as writing is digits and signs,
/// the rest are drawings and short waves. The same at every run: the wobble comes from fixed formulas and a
/// fixed pseudo-random sequence (`HandRandom`), never from the system's random numbers.
///
/// Where things go: the points are cell-relative lu (the cell's top left is 0, 0), as in a stored page.
/// - A month cell is 200 wide. The number is at y 4–28, the all-day lanes from y 28 (25 each), the timed chips
///   after them (20 each). Every stroke keeps to the cell's free part for both week starts (a stroke's bottom
///   stays above 163, so the row of 175 does not grow; `ScreenshotModeTests` checks all of this on the layouts).
/// - The week and the day have one cell, `grid`: x and y are the paper's. A week column is 190.857 wide, an hour
///   80 high, and the columns follow the week start; a day's hour is 100 high, its timeline x 72–660, its memo
///   x 660–1000. The zoom differs by language (pt-BR's taller heading makes the columns about 2 % narrower on an
///   iPhone), but the paper's coordinates do not.
/// - A year cell is 112 wide: number and letter at y 3–21 on the left, chips on the right from x 50.4, and a
///   stroke's bottom stays above 48 (rows of 60 do not grow). No stroke in a cell of a date that does not exist.
extension ScreenshotMode {
    /// The App Store's page of `kind`. The ids are "store-<page>-<what>-<n>".
    static func storeInkPage(kind: PageKind, focus: DayKey, weekStart: WeekStart) -> InkPage {
        switch kind {
        case .month: return StoreInk.monthPage(YearMonth(year: focus.year, month: focus.month))
        case .week: return StoreInk.weekPage(focus: focus, weekStart: weekStart)
        case .day: return StoreInk.dayPage(focus: focus)
        case .year: return StoreInk.yearPage(focus: focus)
        }
    }
}

private enum StoreInk {
    // MARK: Month

    static func monthPage(_ month: YearMonth) -> InkPage {
        var book = InkBook(prefix: "store-month", pageId: month.inkPageId, seed: 101)
        func day(_ d: Int) -> CellKey {
            .day(DayKey(year: month.year, month: month.month, day: min(d, DayKey.daysInMonth(year: month.year, month: month.month))))
        }

        // Today: around the number (its disc is at x 4–28, y 4–28).
        book.loop("circle", cell: day(7), center: CGPoint(x: 16, y: 16), rx: 20, ry: 16, color: InkBook.red)

        // Days that are done.
        book.check("check", cell: day(2), x: 34, y: 92, size: 34)
        book.check("check", cell: day(6), x: 34, y: 92, size: 34)
        book.check("check", cell: day(19), x: 80, y: 74, size: 40)
        book.check("check", cell: day(26), x: 76, y: 78, size: 38)

        // A star and a heart, here and there. The heart under 「birthday」 of the 16th (the row is 188 high there).
        book.star("star", cell: day(24), center: CGPoint(x: 100, y: 100), radius: 40, color: InkBook.blue)
        book.star("star", cell: day(10), center: CGPoint(x: 120, y: 112), radius: 30, color: InkBook.red)
        book.heart("heart", cell: day(16), center: CGPoint(x: 100, y: 152), size: 20)
        book.heart("heart", cell: day(30), center: CGPoint(x: 96, y: 92), size: 32)

        // An arrow from the 14th to the 15th (a Wednesday and a Thursday: side by side for both week starts).
        book.digits("time", "9:30", cell: day(14), x: 38, y: 50, height: 28, color: InkBook.ink)
        book.arrow("arrow", cell: day(14), from: CGPoint(x: 60, y: 104), control: CGPoint(x: 180, y: 76), to: CGPoint(x: 298, y: 104), color: InkBook.blue)
        book.check("check", cell: day(15), x: 118, y: 80, size: 40)

        // Times in digits, none of them on a band or a chip: on the free part of the 8th, the 21st and the 29th.
        book.digits("time", "17:00", cell: day(8), x: 40, y: 96, height: 26, color: InkBook.blue)
        book.digits("time", "8:15", cell: day(21), x: 36, y: 76, height: 28, color: InkBook.ink)
        book.marker("marker", cell: day(29), from: CGPoint(x: 26, y: 105), to: CGPoint(x: 146, y: 103))
        book.digits("time", "19:00", cell: day(29), x: 36, y: 88, height: 30, color: InkBook.ink)

        // The camping days: a small tent under the band of the 4th, trees under the band of the 5th.
        book.tent("tent", cell: day(4), x: 44, y: 66, scale: 1)
        book.tree("tree", cell: day(5), x: 56, y: 62, scale: 1)
        book.tree("tree", cell: day(5), x: 112, y: 86, scale: 0.7)

        // A line that reads like a word, on the free part of a few days.
        book.wave("wave", cell: day(13), x: 26, y: 88, length: 118)
        book.wave("wave", cell: day(23), x: 26, y: 104, length: 92)

        // The notes: three lines with a box and a check, a short wave beside them, a small drawing, a date.
        for (index, words) in [[210, 70], [130], [170, 90]].enumerated() {
            let rule = CGFloat(100 + 50 * index)
            book.box("memo-box", cell: .memo, x: 40, y: rule - 36, size: 28)
            book.check("memo-check", cell: .memo, x: 44, y: rule - 46, size: 36)
            var x: CGFloat = 96
            for length in words {
                book.wave("memo-wave", cell: .memo, x: x, y: rule - 20, length: CGFloat(length))
                x += CGFloat(length) + 26
            }
        }
        book.mountains("memo-mountain", cell: .memo, x: 560, y: 80, scale: 1.25)
        book.sun("memo-sun", cell: .memo, center: CGPoint(x: 800, y: 74), radius: 26)
        book.digits("memo-date", "10/24", cell: .memo, x: 1010, y: 62, height: 34, color: InkBook.blue)
        book.arrow("memo-arrow", cell: .memo, from: CGPoint(x: 1120, y: 80), control: CGPoint(x: 1150, y: 72), to: CGPoint(x: 1186, y: 80), color: InkBook.blue)
        book.digits("memo-date", "10/26", cell: .memo, x: 1200, y: 62, height: 34, color: InkBook.blue)
        book.wave("memo-wave", cell: .memo, x: 1012, y: 132, length: 150)
        book.heart("memo-heart", cell: .memo, center: CGPoint(x: 1200, y: 130), size: 18)
        return book.page
    }

    // MARK: Week

    static func weekPage(focus: DayKey, weekStart: WeekStart) -> InkPage {
        var book = InkBook(prefix: "store-week", pageId: PageNavigation.pageId(.week, focus: focus, weekStart: weekStart), seed: 202)
        let first = weekStart.firstDay(of: focus)
        /// Paper x of `dx` inside the column of `weekday` (0 = Sunday), wherever the week start puts it.
        func x(_ weekday: Int, _ dx: CGFloat) -> CGFloat {
            PaperSpec.weekGutter + CGFloat((weekday - first.weekday + 7) % 7) * PaperSpec.weekColumnWidth + dx
        }
        func y(_ hour: CGFloat) -> CGFloat { hour * PaperSpec.weekHourHeight }
        let (sunday, monday, tuesday, wednesday, thursday, friday, saturday) = (0, 1, 2, 3, 4, 5, 6)

        book.digits("time", "8:00", cell: .grid, x: x(sunday, 44), y: y(8.25), height: 30, color: InkBook.ink)
        book.tree("tree", cell: .grid, x: x(sunday, 66), y: y(12), scale: 1)

        book.digits("time", "9:30", cell: .grid, x: x(monday, 30), y: y(9.2), height: 30, color: InkBook.ink)
        book.check("check", cell: .grid, x: x(monday, 124), y: y(9.05), size: 36)
        book.tent("tent", cell: .grid, x: x(monday, 44), y: y(13), scale: 1)

        book.digits("time", "12:30", cell: .grid, x: x(tuesday, 42), y: y(12.3), height: 30, color: InkBook.blue)
        book.loop("circle", cell: .grid, center: CGPoint(x: x(tuesday, 88), y: y(12.3) + 15), rx: 66, ry: 32, color: InkBook.red)
        book.check("check", cell: .grid, x: x(tuesday, 74), y: y(16.1), size: 40)

        book.marker("marker", cell: .grid, from: CGPoint(x: x(wednesday, 26), y: y(17.25) + 2), to: CGPoint(x: x(wednesday, 142), y: y(17.25)))
        book.digits("time", "17:00", cell: .grid, x: x(wednesday, 36), y: y(17.1), height: 30, color: InkBook.ink)
        book.arrow("arrow", cell: .grid, from: CGPoint(x: x(wednesday, 92), y: y(17.8)), control: CGPoint(x: x(wednesday, 180), y: y(18.5)), to: CGPoint(x: x(thursday, 62), y: y(18.25)), color: InkBook.blue)
        book.star("star", cell: .grid, center: CGPoint(x: x(thursday, 104), y: y(18.2)), radius: 32, color: InkBook.blue)

        book.heart("heart", cell: .grid, center: CGPoint(x: x(thursday, 95), y: y(11.5)), size: 28)

        book.check("check", cell: .grid, x: x(friday, 74), y: y(10.4), size: 40)
        book.digits("time", "19:00", cell: .grid, x: x(friday, 40), y: y(19.1), height: 30, color: InkBook.ink)
        book.wave("wave", cell: .grid, x: x(friday, 40), y: y(19.9), length: 104)

        book.mountains("mountain", cell: .grid, x: x(saturday, 22), y: y(9.5), scale: 0.72)
        book.sun("sun", cell: .grid, center: CGPoint(x: x(saturday, 150), y: y(9.5)), radius: 16)
        book.star("star", cell: .grid, center: CGPoint(x: x(saturday, 95), y: y(15.4)), radius: 30, color: InkBook.red)
        return book.page
    }

    // MARK: Day

    static func dayPage(focus: DayKey) -> InkPage {
        var book = InkBook(prefix: "store-day", pageId: PageNavigation.pageId(.day, focus: focus), seed: 303)
        func y(_ hour: CGFloat) -> CGFloat { hour * PaperSpec.dayHourHeight }

        // The timeline: the free hours around the events of 10:00, 12:30 and 14:00.
        book.digits("time", "8:30", cell: .grid, x: 112, y: y(8.2), height: 38, color: InkBook.ink)
        book.arrow("arrow", cell: .grid, from: CGPoint(x: 224, y: y(8.4)), control: CGPoint(x: 290, y: y(8.25)), to: CGPoint(x: 352, y: y(8.4)), color: InkBook.blue)
        book.star("star", cell: .grid, center: CGPoint(x: 404, y: y(8.38)), radius: 36, color: InkBook.blue)

        book.check("check", cell: .grid, x: 110, y: y(11.6), size: 42)
        book.wave("wave", cell: .grid, x: 172, y: y(11.95), length: 170)

        book.digits("time", "13:30", cell: .grid, x: 112, y: y(13.25), height: 38, color: InkBook.blue)

        book.marker("marker", cell: .grid, from: CGPoint(x: 100, y: y(16.42) + 2), to: CGPoint(x: 262, y: y(16.42)))
        book.digits("time", "16:30", cell: .grid, x: 112, y: y(16.25), height: 38, color: InkBook.ink)
        book.heart("heart", cell: .grid, center: CGPoint(x: 320, y: y(16.42)), size: 28)

        book.digits("time", "19:00", cell: .grid, x: 112, y: y(19.2), height: 38, color: InkBook.ink)
        book.arrow("arrow", cell: .grid, from: CGPoint(x: 262, y: y(19.4)), control: CGPoint(x: 330, y: y(19.6)), to: CGPoint(x: 396, y: y(19.4)), color: InkBook.red)
        book.star("star", cell: .grid, center: CGPoint(x: 450, y: y(19.38)), radius: 34, color: InkBook.red)

        // The memo column: three lines with a box and a check, then a small drawing and a date.
        for (index, length) in [176, 120, 150].enumerated() {
            let rule = CGFloat(100 + 50 * index)
            book.box("memo-box", cell: .grid, x: 686, y: rule - 36, size: 28)
            book.check("memo-check", cell: .grid, x: 690, y: rule - 46, size: 36)
            book.wave("memo-wave", cell: .grid, x: 742, y: rule - 20, length: CGFloat(length))
        }
        book.mountains("memo-mountain", cell: .grid, x: 690, y: 300, scale: 1.05)
        book.sun("memo-sun", cell: .grid, center: CGPoint(x: 900, y: 300), radius: 24)
        book.digits("memo-date", "10/24", cell: .grid, x: 692, y: 500, height: 36, color: InkBook.blue)
        book.wave("memo-wave", cell: .grid, x: 692, y: 574, length: 200)
        book.wave("memo-wave", cell: .grid, x: 692, y: 624, length: 130)
        return book.page
    }

    // MARK: Year

    static func yearPage(focus: DayKey) -> InkPage {
        var book = InkBook(prefix: "store-year", pageId: PageNavigation.pageId(.year, focus: focus), seed: 404)

        // The trip of the sample (the 9th–13th of the month): one marker stroke down the five days, in the
        // narrow way of its nib (about 8 lu), between the weekday's letter and the chips. It is filed under the
        // last day, so that no row grows (a stroke's bottom counts, and the rows above it stay 60 high: the
        // points above the cell are negative).
        book.marker("marker", cell: .yearDay(month: focus.month, day: 13), from: CGPoint(x: 47.5, y: -230), to: CGPoint(x: 47.5, y: 36), wide: false)

        // Red circles around the number (two digits at x 3–22, one digit at x 14–22; the letter starts at 27):
        // today and a few other days.
        let circled = [(focus.month, focus.day), (2, 14), (4, 18), (6, 6), (8, 22), (9, 12), (11, 20), (12, 24)]
        for (month, day) in circled {
            let center = CGPoint(x: day < 10 ? 18 : 12, y: 12.5)
            book.loop("circle", cell: .yearDay(month: month, day: day), center: center, rx: day < 10 ? 8.5 : 11.5, ry: 10.5, color: InkBook.red)
        }

        // Checks on the empty right part of a few days.
        for (month, day) in [(1, 12), (3, 6), (5, 20), (7, 9), (9, 3), (10, 2), (10, 8), (11, 5)] {
            book.check("check", cell: .yearDay(month: month, day: day), x: 66, y: 12, size: 30)
        }
        return book.page
    }
}

// MARK: - The hand

/// A fixed pseudo-random sequence (SplitMix64): the same numbers on every run and every device.
private struct HandRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// The next number, −1…1.
    mutating func next() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return CGFloat(z % 20_001) / 10_000 - 1
    }
}

/// One page being written: every shape is one or more strokes of a hand.
private struct InkBook {
    static let ink = "#1f2937"
    static let blue = "#2563eb"
    static let red = "#dc2626"
    static let green = "#16a34a"
    static let markerYellow = "#fde047"

    /// The toolbar's 細 and 中 (`InkPresets.penWidths`).
    private static let thin = InkPresets.penWidths[0]
    private static let medium = InkPresets.penWidths[1]
    /// A fixed ms epoch, as the other demo strokes have; each stroke gets its own `t`.
    private static let baseTime = 1_760_000_000_000

    private let prefix: String
    private(set) var page: InkPage
    private var count = 0
    private var random: HandRandom

    init(prefix: String, pageId: String, seed: UInt64) {
        self.prefix = prefix
        page = InkPage.empty(pageId: pageId)
        random = HandRandom(seed: seed)
    }

    private mutating func add(_ name: String, cell: CellKey, tool: InkModel.InkTool, color: String, points: [InkPoint]) {
        count += 1
        page.add(InkStroke(id: "\(prefix)-\(name)-\(count)", cell: cell, tool: tool, color: color, t: Self.baseTime + count * 100, points: points))
    }

    private mutating func pen(_ name: String, cell: CellKey, color: String, nib: CGFloat = InkBook.medium, wobble: CGFloat = 0.5, _ segments: [[CGPoint]]) {
        add(name, cell: cell, tool: .pen, color: color, points: handPoints(segments, nib: nib, wobble: wobble))
    }

    // MARK: Shapes

    mutating func check(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, size: CGFloat) {
        pen(name, cell: cell, color: Self.green, Self.shape("0,56 16,74 34,100|34,100 58,52 100,0", x: x, y: y, scale: size / 100)[0])
    }

    /// A loop the hand closes a little past its start.
    mutating func loop(_ name: String, cell: CellKey, center: CGPoint, rx: CGFloat, ry: CGFloat, color: String) {
        let start = -2.3 + 0.2 * random.next()
        let knots = (0...15).map { i -> CGPoint in
            let t = CGFloat(i) / 15
            let angle = start + t * 2 * .pi * 1.08
            let grow = 1 + 0.05 * t
            return CGPoint(x: center.x + rx * grow * cos(angle), y: center.y + ry * grow * sin(angle))
        }
        pen(name, cell: cell, color: color, wobble: 0.3, [knots])
    }

    /// ☆ in one stroke.
    mutating func star(_ name: String, cell: CellKey, center: CGPoint, radius: CGFloat, color: String) {
        let corners = (0...5).map { i -> CGPoint in
            let angle = -CGFloat.pi / 2 + CGFloat(i) * 4 * .pi / 5
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        let segments = (0..<5).map { [corners[$0], corners[$0 + 1]] }
        pen(name, cell: cell, color: color, wobble: 0.7, segments)
    }

    /// ♡ in one stroke, from the dip at the top around to the tip and back. `size` is about its half width.
    mutating func heart(_ name: String, cell: CellKey, center: CGPoint, size: CGFloat) {
        func side(_ range: ClosedRange<CGFloat>) -> [CGPoint] {
            (0...9).map { i -> CGPoint in
                let t = range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(i) / 9
                let sine = sin(t)
                let px = 16 * sine * sine * sine
                let py = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
                return CGPoint(x: center.x + px * size / 16, y: center.y + py * size / 16)
            }
        }
        pen(name, cell: cell, color: Self.red, wobble: 0.3, [side(0...CGFloat.pi), side(CGFloat.pi...(2 * CGFloat.pi))])
    }

    /// → : a curved shaft and, in a second stroke, the two barbs.
    mutating func arrow(_ name: String, cell: CellKey, from: CGPoint, control: CGPoint, to: CGPoint, color: String) {
        let shaft = (0...6).map { i -> CGPoint in
            let t = CGFloat(i) / 6
            let u = 1 - t
            return CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x, y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
        }
        pen(name, cell: cell, color: color, [shaft])
        let angle = atan2(to.y - control.y, to.x - control.x)
        func barb(_ turn: CGFloat) -> CGPoint {
            CGPoint(x: to.x - 22 * cos(angle + turn), y: to.y - 22 * sin(angle + turn))
        }
        pen(name, cell: cell, color: color, [[barb(0.55), to], [to, barb(-0.5)]])
    }

    /// A short wave standing in for a word: small and a little uneven.
    mutating func wave(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, length: CGFloat) {
        let waves = max(2, Int((length / 20).rounded()))
        var knots: [CGPoint] = []
        for i in 0...(2 * waves) {
            let height: CGFloat = i % 2 == 0 ? -1 : 1
            let along = x + length * CGFloat(i) / CGFloat(2 * waves) + 1.2 * random.next()
            let drift = 1.5 * sin(CGFloat(i) * 0.7)
            knots.append(CGPoint(x: along, y: y + drift + height * (4.6 + 1.6 * random.next())))
        }
        pen(name, cell: cell, color: Self.ink, wobble: 0.15, [knots])
    }

    /// A box drawn in one stroke, its corners a little off.
    mutating func box(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, size: CGFloat) {
        let corners = [CGPoint(x: x, y: y + 1), CGPoint(x: x + size + 1, y: y), CGPoint(x: x + size, y: y + size + 1), CGPoint(x: x + 1, y: y + size), CGPoint(x: x, y: y - 1)]
        let segments = (0..<4).map { [corners[$0], corners[$0 + 1]] }
        pen(name, cell: cell, color: Self.ink, wobble: 0.5, segments)
    }

    /// Digits and signs as a hand writes them, each glyph its own strokes; `height` is the height of a digit.
    mutating func digits(_ name: String, _ text: String, cell: CellKey, x: CGFloat, y: CGFloat, height: CGFloat, color: String) {
        var left = x
        for character in text {
            let glyph = Self.glyph(character)
            let scale = height / 100 * (1 + 0.04 * random.next())
            let baseline = y + 0.03 * height * random.next()
            for stroke in Self.shape(glyph.strokes, x: left, y: baseline, scale: scale, slant: 0.1) {
                pen(name, cell: cell, color: color, wobble: 0.25, stroke)
            }
            left += glyph.advance * height
        }
    }

    /// A marker line, in the toolbar's width. Under the pens whatever the order (`InkPage.liveStrokes`). The
    /// marker's nib is flat: drawn along its azimuth the line is narrow (about 8 lu), across it `wide` (18 lu).
    mutating func marker(_ name: String, cell: CellKey, from: CGPoint, to: CGPoint, wide: Bool = true) {
        let length = hypot(to.x - from.x, to.y - from.y)
        let steps = max(4, Int(length / 8))
        let phase = random.next()
        let azimuth = atan2(to.y - from.y, to.x - from.x) + (wide ? .pi / 2 : 0)
        let points = (0...steps).map { i -> InkPoint in
            let t = CGFloat(i) / CGFloat(steps)
            let along = CGFloat(i) * 8
            let side = 0.9 * sin(along / 41 + phase)
            return InkPoint(x: from.x + (to.x - from.x) * t - side * (to.y - from.y) / max(length, 1),
                            y: from.y + (to.y - from.y) * t + side * (to.x - from.x) / max(length, 1), dtMs: i * 15,
                            sizeW: InkPresets.markerWidth, sizeH: InkPresets.markerWidth, opacity: 1, force: 0.4, azimuth: azimuth, altitude: 1.4)
        }
        add(name, cell: cell, tool: .marker, color: Self.markerYellow, points: points)
    }

    // MARK: Small drawings (about 100 lu wide at scale 1)

    mutating func tent(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, scale: CGFloat) {
        for stroke in Self.shape("48,0 0,76|0,76 102,74|102,74 48,0;48,0 46,76;48,28 66,74;-14,84 118,82", x: x, y: y, scale: scale) {
            pen(name, cell: cell, color: Self.ink, stroke)
        }
    }

    mutating func tree(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let strokes = Self.shape("28,0 6,34|6,34 18,32|18,32 0,62|0,62 56,60|56,60 38,32|38,32 50,34|50,34 28,0;28,62 28,84", x: x, y: y, scale: scale)
        pen(name, cell: cell, color: Self.green, strokes[0])
        pen(name, cell: cell, color: Self.ink, strokes[1])
    }

    mutating func mountains(_ name: String, cell: CellKey, x: CGFloat, y: CGFloat, scale: CGFloat) {
        for stroke in Self.shape("0,80 44,24|44,24 66,48|66,48 104,0|104,0 168,80;88,20 98,32 106,22 116,32 122,22;-10,84 180,82", x: x, y: y, scale: scale) {
            pen(name, cell: cell, color: Self.ink, stroke)
        }
    }

    mutating func sun(_ name: String, cell: CellKey, center: CGPoint, radius: CGFloat) {
        loop(name, cell: cell, center: center, rx: radius, ry: radius, color: Self.red)
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 + 0.2 + 0.05 * random.next()
            let from = CGPoint(x: center.x + radius * 1.35 * cos(angle), y: center.y + radius * 1.35 * sin(angle))
            let to = CGPoint(x: center.x + radius * 1.85 * cos(angle), y: center.y + radius * 1.85 * sin(angle))
            pen(name, cell: cell, color: Self.red, wobble: 0.2, [[from, to]])
        }
    }

    // MARK: The strokes of a shape

    /// "x,y x,y|x,y x,y;x,y x,y": strokes are separated by ";", the parts of a stroke (a corner between
    /// them) by "|". Numbers are hundredths of the unit `scale` makes 1 lu of. `slant` leans the top to the right.
    private static func shape(_ text: String, x: CGFloat, y: CGFloat, scale: CGFloat, slant: CGFloat = 0) -> [[[CGPoint]]] {
        text.split(separator: ";").map { stroke in
            stroke.split(separator: "|").map { part in
                part.split(separator: " ").map { pair in
                    let numbers = pair.split(separator: ",").map { CGFloat(Double($0) ?? 0) }
                    return CGPoint(x: x + (numbers[0] + (100 - numbers[1]) * slant) * scale, y: y + numbers[1] * scale)
                }
            }
        }
    }

    /// One glyph: its strokes (100 high, about 60 wide) and how far the next one starts, in heights.
    private static func glyph(_ character: Character) -> (strokes: String, advance: CGFloat) {
        switch character {
        case "0": return ("30,0 9,14 0,50 8,86 30,100 52,86 60,50 52,14 30,0 22,4", 0.78)
        case "1": return ("10,20 30,0|30,0 29,100", 0.52)
        case "2": return ("4,22 16,4 38,0 56,16 50,38 28,66 0,100|0,100 34,96 62,98", 0.78)
        case "3": return ("4,14 24,0 50,8 52,28 26,46|26,46 54,58 60,78 42,97 16,100 0,86", 0.78)
        case "4": return ("42,0 0,68|0,68 64,67;46,30 46,100", 0.8)
        case "5": return ("54,2 12,3 8,44|8,44 32,38 54,50 60,72 44,94 20,100 0,88", 0.78)
        case "6": return ("48,0 20,22 4,55 8,85 30,100 52,88 56,66 38,50 16,54 5,70", 0.78)
        case "7": return ("0,3 60,1|60,1 32,50 20,100", 0.74)
        case "8": return ("52,16 30,0 8,14 14,34 46,62 56,82 30,100 4,82 16,60 46,34 54,18 46,6", 0.78)
        case "9": return ("56,20 36,2 12,8 2,28 14,46 38,46 56,24|56,24 54,62 44,100", 0.78)
        case ":": return ("10,28 14,32 10,36 7,32 10,28;9,70 13,74 9,78 6,74 9,70", 0.34)
        case "/": return ("40,0 0,100", 0.56)
        default: return ("", 0.5)
        }
    }

    // MARK: From a shape to the points of a stroke

    /// The parts of one stroke as stored points: each part a smooth curve through its knots (each knot moved
    /// a little, a corner stays one point), about 2.4 lu between points, with a slow sideways drift and a
    /// pressure that comes and goes and lets go at both ends.
    private mutating func handPoints(_ parts: [[CGPoint]], nib: CGFloat, wobble: CGFloat) -> [InkPoint] {
        var path: [CGPoint] = []
        var corner: CGPoint?
        for part in parts {
            var knots = part.map { CGPoint(x: $0.x + wobble * random.next(), y: $0.y + wobble * random.next()) }
            if let corner, !knots.isEmpty { knots[0] = corner }
            corner = knots.last
            let curve = Self.curve(through: knots)
            path.append(contentsOf: path.isEmpty ? curve[...] : curve.dropFirst())
        }
        guard path.count > 1 else { return [] }

        var distances: [CGFloat] = [0]
        for i in 1..<path.count {
            distances.append(distances[i - 1] + hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
        }
        let total = distances[distances.count - 1]
        let phases = (random.next() * .pi, random.next() * .pi, random.next() * .pi)
        return path.indices.map { i in
            let before = path[max(i - 1, 0)], after = path[min(i + 1, path.count - 1)]
            let length = max(hypot(after.x - before.x, after.y - before.y), 0.001)
            let along = distances[i]
            let drift = wobble * 0.5 * (sin(along / 19 + phases.0) + 0.5 * sin(along / 7.5 + phases.1))
            let pressure = 0.93 + 0.07 * sin(along / 23 + phases.2)
            let ends = min(1, 0.7 + min(along, total - along) / (nib * 6))
            let width = nib * pressure * ends
            return InkPoint(x: path[i].x - drift * (after.y - before.y) / length, y: path[i].y + drift * (after.x - before.x) / length, dtMs: i * 8,
                            sizeW: width, sizeH: width, opacity: 1, force: 0.5 + 0.15 * sin(along / 31 + phases.2), azimuth: 0, altitude: 1.4)
        }
    }

    /// A Catmull-Rom curve through the knots, sampled about every 2.4 lu; two knots are a straight line.
    private static func curve(through knots: [CGPoint]) -> [CGPoint] {
        guard let last = knots.last, knots.count > 1 else { return knots }
        var out: [CGPoint] = []
        for i in 0..<(knots.count - 1) {
            let p0 = knots[max(i - 1, 0)], p1 = knots[i], p2 = knots[i + 1], p3 = knots[min(i + 2, knots.count - 1)]
            let steps = max(2, Int((hypot(p2.x - p1.x, p2.y - p1.y) / 2.4).rounded(.up)))
            for j in 0..<steps {
                let t = CGFloat(j) / CGFloat(steps)
                func blend(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    let e = 2 * b + (c - a) * t
                    let f = (2 * a - 5 * b + 4 * c - d) * t * t
                    let g = (3 * b - a - 3 * c + d) * t * t * t
                    return 0.5 * (e + f + g)
                }
                out.append(CGPoint(x: blend(p0.x, p1.x, p2.x, p3.x), y: blend(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        out.append(last)
        return out
    }
}
