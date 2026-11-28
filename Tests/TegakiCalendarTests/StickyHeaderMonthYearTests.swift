import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §3.8, §4.4, §10, §11.2 row P, §11.5 MP4; 0g-14, 0g-20; role P): the fixed heading of a window
// of joined months (`StickyHeaderView.spanMonthRow`). It is the months' own row — each page's weekday row on its 7 columns,
// never the week's — as tall as the one page's `monthRow`, and each table carries its month's label: the title's month
// (`DateText.monthName(m, .full, …)`), its short name or the number when the column is narrow, none when even that does not fit
// (one form for the whole row, `monthLabelForm`); a table that went out to the left keeps its label at the screen's left edge
// until the next table's label pushes it out (`monthLabelX`); each label is one heading element for VoiceOver, read once.
//
// The rows are drawn the way the frozen PaperSpanTests draws the heading (`ImageRenderer` at 1 px per point). The zooms are the
// month's: the iPhone 17 in portrait opens at 402 / 1,400 (57.4 pt columns), the 11-inch iPad in landscape at 640 / 1,050
// (1,210 × 640 pt), the 13-inch at 830 / 1,050 and its 等倍 1,366 / 1,400. The year's row (`spanYearRow`) is D1y's.

@MainActor
final class StickyHeaderMonthYearTests: XCTestCase {
    /// 2026-11-11, a Wednesday, 10:00: no month of the window is shown with a label of today.
    private let now = DayKey(year: 2026, month: 11, day: 11).startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600)

    private let iPhonePortrait: CGFloat = 402.0 / 1_400
    private let iPad11Landscape: CGFloat = 640.0 / 1_050
    private let iPad13Landscape: CGFloat = 830.0 / 1_050
    private let iPad13LandscapeFit: CGFloat = 1_366.0 / 1_400

    // MARK: - Helpers

    private func month(_ year: Int, _ month: Int, weekStart: WeekStart = .monday) throws -> PaperContent {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: year, month: month), events: [], inkBottoms: [:], now: now,
                                                               weekStart: weekStart))
        return try XCTUnwrap(PaperSpan.paperContent(of: layout))
    }

    /// October, November and December 2026 joined, the focus on November.
    private func window(weekStart: WeekStart = .monday) throws -> PaperSpan {
        let pages = [try month(2026, 10, weekStart: weekStart), try month(2026, 11, weekStart: weekStart), try month(2026, 12, weekStart: weekStart)]
        return try XCTUnwrap(PaperSpan(pages: pages, bands: [], focus: 1))
    }

    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The pixels of x × all rows darker than 170 in every channel: the label's `ink2` (#4b5563) and the weekdays'
        /// primary, not the row's background (#f2f2f7) or its separator (#c6c6c8, half a point).
        func darkPixels(x: Range<Int>) -> Int {
            var count = 0
            for yy in 0..<height {
                for xx in x {
                    let p = pixel(xx, yy)
                    if p.r >= 0, p.r < 170, p.g < 170, p.b < 170 { count += 1 }
                }
            }
            return count
        }

        /// The pixels of the two bitmaps' column ranges (same width, every row of the shorter) that differ by more than
        /// `tolerance` in a channel.
        static func differences(_ a: Bitmap, x0: Int, _ b: Bitmap, x1: Int, width: Int, tolerance: Int = 0) -> Int {
            var count = 0
            for y in 0..<min(a.height, b.height) {
                for x in 0..<width {
                    let p = a.pixel(x0 + x, y)
                    let q = b.pixel(x1 + x, y)
                    if abs(p.r - q.r) > tolerance || abs(p.g - q.g) > tolerance || abs(p.b - q.b) > tolerance { count += 1 }
                }
            }
            return count
        }
    }

    /// A SwiftUI view laid out at `width` (its own height) and drawn at 1 px per point (PaperSpanTests' `render`).
    private func render<V: View>(_ view: V, width: CGFloat) throws -> Bitmap {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 1
        let cg = try XCTUnwrap(renderer.cgImage, "ImageRenderer gave no picture")
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // No flip: the image's top row lands in the first row of the buffer (PaperViewTests).
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return Bitmap(bytes: bytes, width: cg.width, height: cg.height)
    }

    private func heading(_ paper: PaperContent, _ viewport: PaperViewport, span: PaperSpan? = nil, language: UILanguage = L.language) -> StickyHeaderView {
        StickyHeaderView(paper: paper, now: now, viewport: viewport, span: span, language: language, onDayTap: { _ in }, onMonthTap: { _ in })
    }

    /// The widest weekday of the month's row in `language` (Monday first), as the row measures it.
    private func weekdayPoints(_ language: UILanguage, weekStart: WeekStart = .monday) -> CGFloat {
        StickyHeaderView.monthWeekdayPoints(PaperWords.monthHeaderWeekdays(language, weekStart: weekStart))
    }

    private func form(_ zoom: CGFloat, _ language: UILanguage) -> StickyHeaderView.MonthLabelForm? {
        StickyHeaderView.monthLabelForm(columnPoints: PaperSpec.monthColumnWidth * zoom, weekdayPoints: weekdayPoints(language), language: language)
    }

    /// The widest label of the twelve months in `form` (pt).
    private func widest(_ form: StickyHeaderView.MonthLabelForm, _ language: UILanguage) -> CGFloat {
        (1...12).map { StickyHeaderView.monthLabelWidth(StickyHeaderView.monthLabelText(month: $0, form: form, language: language)) }.max() ?? 0
    }

    // MARK: - The row (MP4)

    /// MP4, §3.8, 0g-20: the joined months draw their own row: at zoom 0.5 (100 pt columns) every page's weekday columns 2–7
    /// are, pixel for pixel, the one page's `monthRow` of that month, each page from its origin (x = k × 700 pt), and the row is
    /// as tall as the one page's — the week's row (`spanWeekRow`, 48 pt cells) would be taller and would draw dates. The first
    /// column of each page carries the label, which the one page's row does not have.
    func testTheJoinedMonthsDrawTheMonthsRowFromEachOrigin() throws {
        let joined = try window()
        let zoom: CGFloat = 0.5
        let page = PaperSpec.monthWidth * zoom
        let row = try render(heading(joined.pages[1], PaperViewport(offsetX: 0, zoom: zoom, width: 3 * page), span: joined), width: 3 * page)
        let column = Int(PaperSpec.monthColumnWidth * zoom)
        XCTAssertEqual(column, 100)
        for slot in 0..<3 {
            let alone = try render(heading(joined.pages[slot], PaperViewport(offsetX: 0, zoom: zoom, width: page)), width: page)
            XCTAssertGreaterThan(alone.height, 15, "slot \(slot)")
            XCTAssertLessThan(alone.height, 48, "the month's weekday row, not the week's 48 pt cells")
            XCTAssertEqual(row.height, alone.height, "slot \(slot): the joined row is as tall as the one page's")
            let origin = slot * Int(page)
            XCTAssertEqual(Bitmap.differences(row, x0: origin + column, alone, x1: column, width: Int(page) - column, tolerance: 8), 0,
                           "slot \(slot): the weekday columns 2–7 at the page's origin are the one page's")
            // The label 「10月」…「12月」 in the first column, left of its weekday 「月」 (centred at 50 pt, about 12 pt wide).
            XCTAssertGreaterThan(row.darkPixels(x: (origin + 2)..<(origin + 38)), 0, "slot \(slot): the month's label")
            XCTAssertEqual(alone.darkPixels(x: 2..<38), 0, "slot \(slot): the one page's row has no label")
        }
    }

    /// §3.8 (the paper area and the opening zoom are the one page's): the joined row is exactly as tall as the one page's
    /// `monthRow` at every month zoom — the iPhone's opening (labels as numbers or none), the iPads' in landscape (short or full
    /// names), 1 and a narrow 0.1 (no label) — with the label's language ja, en or de, scrolled or not: the labels lie over the
    /// row and never make it taller.
    func testTheJoinedRowIsAsTallAsTheOnePagesRow() throws {
        let joined = try window()
        var compared = 0
        for zoom in [iPhonePortrait, iPad11Landscape, iPad13Landscape, iPad13LandscapeFit, 1, 0.1] {
            let width = (PaperSpec.monthWidth * zoom).rounded(.up)
            let alone = try render(heading(joined.pages[1], PaperViewport(offsetX: 0, zoom: zoom, width: width)), width: width)
            XCTAssertGreaterThan(alone.height, 15)
            for language in [UILanguage.ja, .en, .de] {
                for offset in [CGFloat(0), (PaperSpec.monthWidth * zoom * 0.6).rounded()] {
                    let viewport = PaperViewport(offsetX: offset, zoom: zoom, width: width)
                    let row = try render(heading(joined.pages[1], viewport, span: joined, language: language), width: width)
                    XCTAssertEqual(row.height, alone.height, "zoom \(zoom), \(language.rawValue), offset \(offset)")
                    compared += 1
                }
            }
        }
        XCTAssertEqual(compared, 6 * 3 * 2)
    }

    // MARK: - The label's words (§4.4)

    /// §4.4, 0g-14: the label is the title's month — `DateText.monthName(m, .full, language)`, which the month page's title
    /// (`PageNavigation.title(.month, …)`) holds: ja 「11月」 of 「2026年11月」, en and de "November" of "November 2026" — then the
    /// short name and the number alone, no new string. VoiceOver reads the full name whatever the form.
    func testTheLabelIsTheTitlesMonth() throws {
        for language in [UILanguage.ja, .en, .de] {
            for m in 1...12 {
                let full = StickyHeaderView.monthLabelText(month: m, form: .full, language: language)
                XCTAssertEqual(full, DateText.monthName(m, .full, language))
                XCTAssertFalse(full.isEmpty)
                let title = PageNavigation.title(.month, focus: DayKey(year: 2026, month: m, day: 15), language: language)
                XCTAssertTrue(title.contains(full), "\(language.rawValue) \(m): \(full) in the title \(title)")
                XCTAssertEqual(StickyHeaderView.monthLabelText(month: m, form: .short, language: language), DateText.monthName(m, .short, language))
                XCTAssertEqual(StickyHeaderView.monthLabelText(month: m, form: .number, language: language), String(m))
            }
        }
        XCTAssertEqual(StickyHeaderView.monthLabelText(month: 11, form: .full, language: .ja), "11月")
        XCTAssertEqual(StickyHeaderView.monthLabelText(month: 11, form: .number, language: .ja), "11")

        let joined = try window()
        for language in [UILanguage.ja, .en, .de] {
            for zoom in [iPhonePortrait, iPad11Landscape, iPad13LandscapeFit] {
                let viewport = PaperViewport(offsetX: 0, zoom: zoom, width: 3 * PaperSpec.monthWidth * zoom)
                let labels = StickyHeaderView.monthLabels(joined, viewport: viewport, language: language, weekdayPoints: weekdayPoints(language))
                for label in labels {
                    XCTAssertEqual(label.spoken, DateText.monthName(label.month.month, .full, language), "\(language.rawValue) at \(zoom)")
                    let form = try XCTUnwrap(self.form(zoom, language))
                    XCTAssertEqual(label.text, StickyHeaderView.monthLabelText(month: label.month.month, form: form, language: language))
                }
            }
        }
    }

    /// §4.4 (the narrow screen), §11.2: one form for the whole row, the first whose widest month fits beside the weekday — the
    /// full name, then the short one, then the number, then none — measured in ja, en and de:
    /// - the 13-inch iPad in landscape at 等倍 (195 pt columns): the full name in all three; at its opening (158 pt) the full
    ///   name in ja, the full or the short one in en and de;
    /// - the 11-inch iPad in landscape at its opening (122 pt): ja 「11月」, en "Nov" and de "Nov." (or whatever its short name
    ///   is): "September" does not fit;
    /// - the iPhone in portrait at its opening (57.4 pt): the number in ja (「11」 beside 「月」), none in en ("Wed" leaves 14 pt),
    ///   the number or none in de;
    /// - 20 pt columns: none.
    /// The form changes exactly where the widest month of a form fits, and never goes back to a longer one on a narrower column.
    func testTheLabelShrinksToTheNumberThenGoes() throws {
        for language in [UILanguage.ja, .en, .de] {
            XCTAssertEqual(form(iPad13LandscapeFit, language), .full, "\(language.rawValue): the 13-inch iPad's 等倍")
            XCTAssertNil(form(20 / PaperSpec.monthColumnWidth, language), "\(language.rawValue): 20 pt columns")
        }
        XCTAssertEqual(form(iPad13Landscape, .ja), .full)
        XCTAssertTrue([.full, .short].contains(form(iPad13Landscape, .en)), "\(String(describing: form(iPad13Landscape, .en)))")
        XCTAssertTrue([.full, .short].contains(form(iPad13Landscape, .de)), "\(String(describing: form(iPad13Landscape, .de)))")
        XCTAssertEqual(form(iPad11Landscape, .ja), .full)
        XCTAssertEqual(form(iPad11Landscape, .en), .short)
        XCTAssertEqual(form(iPad11Landscape, .de), .short)
        XCTAssertEqual(PaperSpec.monthColumnWidth * iPhonePortrait, 57.43, accuracy: 0.01)
        XCTAssertEqual(form(iPhonePortrait, .ja), .number)
        XCTAssertNil(form(iPhonePortrait, .en))
        XCTAssertTrue([nil, .number].contains(form(iPhonePortrait, .de)), "\(String(describing: form(iPhonePortrait, .de)))")

        let order: [StickyHeaderView.MonthLabelForm?] = [nil, .number, .short, .full]
        for language in [UILanguage.ja, .en, .de] {
            let weekday = weekdayPoints(language)
            // Where each form starts to fit: inset + widest ≤ (column − weekday) / 2 − gap.
            for candidate in StickyHeaderView.MonthLabelForm.allCases {
                let threshold = 2 * (StickyHeaderView.monthLabelInset + widest(candidate, language) + StickyHeaderView.monthLabelGap) + weekday
                let at = StickyHeaderView.monthLabelForm(columnPoints: threshold + 0.001, weekdayPoints: weekday, language: language)
                let below = StickyHeaderView.monthLabelForm(columnPoints: threshold - 0.001, weekdayPoints: weekday, language: language)
                XCTAssertNotNil(at, "\(language.rawValue) \(candidate)")
                XCTAssertGreaterThanOrEqual(order.firstIndex(of: at) ?? -1, order.firstIndex(of: candidate) ?? 99,
                                            "\(language.rawValue): \(candidate) or a longer form fits at \(threshold) pt")
                if at == candidate {
                    XCTAssertNotEqual(below, candidate, "\(language.rawValue): \(candidate) does not fit below \(threshold) pt")
                }
            }
            var last = -1
            for tenth in stride(from: 100, through: 2_600, by: 5) {
                let found = StickyHeaderView.monthLabelForm(columnPoints: CGFloat(tenth) / 10, weekdayPoints: weekday, language: language)
                let rank = try XCTUnwrap(order.firstIndex(of: found))
                XCTAssertGreaterThanOrEqual(rank, last, "\(language.rawValue) at \(CGFloat(tenth) / 10) pt: never back to a shorter form")
                last = rank
            }
            XCTAssertEqual(last, 3, "\(language.rawValue): the full name at 260 pt")
        }
        // Unusable widths: no label.
        XCTAssertNil(StickyHeaderView.monthLabelForm(columnPoints: .nan, weekdayPoints: 12, language: .ja))
        XCTAssertNil(StickyHeaderView.monthLabelForm(columnPoints: 0, weekdayPoints: 12, language: .ja))
        XCTAssertNil(StickyHeaderView.monthLabelForm(columnPoints: 200, weekdayPoints: .infinity, language: .ja))
    }

    // MARK: - Sticking (§4.4)

    /// §4.4: a label stands 2 pt right of its table's left edge; once that edge has gone out to the left it stays 2 pt from the
    /// screen's left edge while its table is on screen, until the next table's label, coming in at the boundary, pushes it out
    /// (it never passes its own table's right edge less 2 pt); a table off the screen has none. On screen (the 11-inch iPad's
    /// landscape opening, 853 pt pages) the stuck label is drawn at the left edge.
    func testALabelSticksToTheLeftEdgeUntilTheNextPushesItOut() throws {
        let zoom = iPad11Landscape
        let page = PaperSpec.monthWidth * zoom
        let width: CGFloat = 1_210
        let w: CGFloat = 30
        let inset = StickyHeaderView.monthLabelInset
        func x(_ slot: Int, _ offset: CGFloat, width: CGFloat = 1_210) -> CGFloat? {
            StickyHeaderView.monthLabelX(slot: slot, labelWidth: w, viewport: PaperViewport(offsetX: offset, zoom: zoom, width: width))
        }
        // At rest: each label at its table's left edge.
        XCTAssertEqual(try XCTUnwrap(x(0, 0)), inset, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(x(1, 0)), page + inset, accuracy: 1e-9)
        XCTAssertNil(x(2, 0), "the third table has not come in (it starts at \(2 * page) pt)")
        // The first table 300 pt out to the left: its label sticks, the second follows its table.
        XCTAssertEqual(try XCTUnwrap(x(0, 300)), inset, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(x(1, 300)), page - 300 + inset, accuracy: 1e-9)
        // The first table's right edge at 20 pt: its label is pushed (its right edge 2 pt short of the boundary).
        let pushed = page - 20
        XCTAssertEqual(try XCTUnwrap(x(0, pushed)), 20 - inset - w, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(x(1, pushed)), 20 + inset, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(try XCTUnwrap(x(0, pushed)) + w, try XCTUnwrap(x(1, pushed)) - 2 * inset + 1e-9, "no overlap")
        // Its table gone (its right edge at 0, then left of it): no label; the next one sticks.
        XCTAssertNil(x(0, page))
        XCTAssertNil(x(0, page + 50))
        XCTAssertEqual(try XCTUnwrap(x(1, page + 50)), inset, accuracy: 1e-9)
        // The last table of the window keeps its label inside it too; one wider than the screen sticks.
        XCTAssertEqual(try XCTUnwrap(x(2, 2 * page + 100)), inset, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(x(2, 3 * page - 20)), 20 - inset - w, accuracy: 1e-9)
        // A paper narrower than the screen, centred (negative offset): at its table's edge.
        XCTAssertEqual(try XCTUnwrap(x(0, -100, width: 4_000)), 100 + inset, accuracy: 1e-9)
        // Off the right edge, a table too narrow for its label, unusable values: none.
        XCTAssertNil(x(1, -width))
        XCTAssertNil(StickyHeaderView.monthLabelX(slot: 0, labelWidth: w, viewport: PaperViewport(offsetX: 0, zoom: 0.02, width: width)))
        XCTAssertNil(StickyHeaderView.monthLabelX(slot: 0, labelWidth: w, viewport: PaperViewport(offsetX: .nan, zoom: zoom, width: width)))
        XCTAssertNil(StickyHeaderView.monthLabelX(slot: 0, labelWidth: 0, viewport: PaperViewport(offsetX: 0, zoom: zoom, width: width)))

        // The labels of the window move with it.
        let joined = try window()
        let weekday = weekdayPoints(.ja)
        let rest = StickyHeaderView.monthLabels(joined, viewport: PaperViewport(offsetX: 0, zoom: zoom, width: width), language: .ja, weekdayPoints: weekday)
        XCTAssertEqual(rest.map(\.slot), [0, 1])
        XCTAssertEqual(rest.map(\.text), ["10月", "11月"])
        // Scrolled by 250 pt (October's third weekday centred at 55 pt, clear of the label): October's label sticks.
        let scrolled = StickyHeaderView.monthLabels(joined, viewport: PaperViewport(offsetX: 250, zoom: zoom, width: width), language: .ja, weekdayPoints: weekday)
        XCTAssertEqual(scrolled.map(\.slot), [0, 1], "December's table starts at \(2 * page - 250) pt")
        XCTAssertEqual(scrolled.first?.x ?? -1, inset, accuracy: 1e-9, "October's label sticks")
        XCTAssertEqual(scrolled.last?.x ?? -1, page - 250 + inset, accuracy: 1e-9)

        // On screen: October's label is drawn at the left edge, where October's first weekday cells have gone.
        let row = try render(heading(joined.pages[1], PaperViewport(offsetX: 250, zoom: zoom, width: width), span: joined, language: .ja), width: width)
        let label = try XCTUnwrap(scrolled.first)
        let under = Int(inset.rounded(.up))..<Int((inset + label.width).rounded(.down))
        XCTAssertGreaterThan(row.darkPixels(x: under), 0, "the stuck label")
        let still = try render(heading(joined.pages[1], PaperViewport(offsetX: 250, zoom: zoom, width: width)), width: width)
        XCTAssertEqual(still.darkPixels(x: under), 0, "November's one page scrolled by 250 pt has nothing there")
    }

    // MARK: - VoiceOver (§10)

    /// §10: each label is one heading element that reads the title's month; a label stuck at the left edge is its own table's
    /// label moved (one per page, never a copy), so VoiceOver reads it once. A window of one page, a window of weeks and the one
    /// page's heading have no label.
    func testEachLabelIsOneHeadingReadOnce() throws {
        let joined = try window()
        let zoom = iPad11Landscape
        let page = PaperSpec.monthWidth * zoom
        for language in [UILanguage.ja, .en, .de] {
            let weekday = weekdayPoints(language)
            for step in 0...40 {
                let offset = CGFloat(step) * page / 16 - page / 4
                let viewport = PaperViewport(offsetX: offset, zoom: zoom, width: 1_210)
                let labels = StickyHeaderView.monthLabels(joined, viewport: viewport, language: language, weekdayPoints: weekday)
                XCTAssertEqual(Set(labels.map(\.slot)).count, labels.count, "\(language.rawValue) at \(offset): one label per page")
                XCTAssertEqual(labels.map(\.slot), labels.map(\.slot).sorted())
                for label in labels {
                    guard case .month(let content) = joined.pages[label.slot] else { return XCTFail("a month") }
                    XCTAssertEqual(label.month, content.layout.month, "the label is its own page's")
                    XCTAssertEqual(label.spoken, DateText.monthName(content.layout.month.month, .full, language))
                    XCTAssertGreaterThan(label.x + label.width, 0)
                    XCTAssertLessThan(label.x, viewport.width)
                }
                for (a, b) in zip(labels, labels.dropFirst()) {
                    XCTAssertLessThanOrEqual(a.x + a.width, b.x + 1e-9, "\(language.rawValue) at \(offset): labels never overlap")
                }
            }
        }
        let viewport = PaperViewport(offsetX: 0, zoom: zoom, width: 1_210)
        let one = try XCTUnwrap(PaperSpan(pages: [try month(2026, 11)], bands: [], focus: 0))
        XCTAssertEqual(StickyHeaderView.monthLabels(one, viewport: viewport, language: .ja, weekdayPoints: 12), [], "a window of one page")

        // The label's view: one element, a heading, that reads `spoken` (the source of StickyHeaderView.swift, as the screen's
        // guarded lines are read by the frozen tests).
        let repository = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: repository.appendingPathComponent("Sources/TegakiCalendar/Views/StickyHeaderView.swift"), encoding: .utf8)
        let flat = source.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        func count(_ text: String, in text2: String) -> Int { text2.components(separatedBy: text).count - 1 }
        let view = try XCTUnwrap(flat.components(separatedBy: "private struct SpanMonthLabelView: View {").dropFirst().first?
            .components(separatedBy: "extension YearMonth").first, "the label's view")
        XCTAssertEqual(count(".accessibilityElement(children: .ignore) .accessibilityLabel(label.spoken) .accessibilityAddTraits(.isHeader)", in: view), 1,
                       "the label is one heading element reading the title's month")
        XCTAssertEqual(count("SpanMonthLabelView(label: label)", in: flat), 1, "one view per label, placed where `monthLabels` says")
    }
}
