import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// The words of the paper and of the headings against their boxes, in all ten languages, measured
/// with the simulator's UIKit (1.2, docs/M7B_CONTRACT.md §4.1 F-0–F-11, §4.5 F-16, §7.2, §10.8). The
/// app's words come from `L.text(_, in:)`, the Kit's from `KitStrings`. These tests run in Japanese
/// (`-testLanguage ja`, 0-25), so `L.language` is ja and the composed sentences are 1.1's (J-1).
@MainActor
final class PaperFitTests: XCTestCase {
    private let languages = UILanguage.allCases
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func width(_ text: String, _ font: UIFont) -> CGFloat {
        PaperText.naturalWidth(of: text, font: font)
    }

    private func month(_ weekStart: WeekStart) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now, weekStart: weekStart))
    }

    // MARK: - §7.2

    /// F-1: the seven signs of every language fit the box at one scale, not below the floor, in the
    /// heavy weight of today's cell (the widest).
    func testYearWeekdaysFitInEveryLanguage() {
        let size = PaperText.yearWeekday.lu
        let pad = PaperSpec.yearPad
        for language in languages {
            let box = YearPaper.weekdayBoxWidth(weekdaySize: size, pad: pad, language)
            XCTAssertEqual(box, language == .ja ? 21 : 23.4, accuracy: 0.001, "the box of \(language)")
            let scale = PaperWords.yearWeekdayScale(boxWidth: box, fontSize: size, language)
            if language == .ja {
                XCTAssertNil(scale, "ja: 1.1's drawLine")
            } else {
                let rate = scale ?? 0
                XCTAssertGreaterThanOrEqual(rate, PaperWords.yearWeekdayMinScale, "the scale of \(language)")
                XCTAssertLessThanOrEqual(rate, 1, "the scale of \(language)")
            }
            let font = UIFont.systemFont(ofSize: size * (scale ?? 1), weight: .heavy)
            for weekday in 0..<7 {
                let sign = PaperWords.yearWeekday(weekday, language)
                XCTAssertFalse(sign.isEmpty)
                XCTAssertLessThanOrEqual(width(sign, font), box + 0.05, "\(language) \(sign) is cut in a year cell")
            }
        }
        // The contract's one language that needs it (§3.3: three letters).
        let portuguese = PaperWords.yearWeekdayScale(boxWidth: 23.4, fontSize: size, .ptBR) ?? 0
        XCTAssertLessThan(portuguese, 0.9, "pt-BR's signs are three letters")
        XCTAssertEqual(PaperWords.yearWeekdayScale(boxWidth: 23.4, fontSize: size, .ko) ?? 0, 1, "Korean signs fit as they are")
    }

    /// F-6: 「幅 ＋ 0.15 em × 字数」 at most 8.0 em, for both labels.
    func testMemoLabelsFit() {
        let size: CGFloat = 20
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        for language in languages {
            for key in ["paper.memo", "paper.freeMemo"] {
                let text = L.text(key, in: language)
                let ems = width(text, font) / size + 0.15 * CGFloat(text.count)
                XCTAssertLessThanOrEqual(ems, 8.0, "\(key) in \(language): \(text)")
            }
        }
    }

    /// F-5: 「+99 …」 at most 7 em; the chip is 192 lu wide and its text is at most 20 lu, so 8.9 em fit.
    func testMoreChipsFit() {
        let size: CGFloat = 20
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        for language in languages {
            let words = LayoutWords.of(language)
            for count in [1, 2, 99] {
                let text = words.more(count)
                XCTAssertTrue(text.contains(String(count)), "\(language): \(text)")
                XCTAssertLessThanOrEqual(width(text, font) / size, 7, "\(language): \(text)")
            }
        }
    }

    /// F-7: the word shown in the gutter of the band fits it, or there is none; ja is always 1.1's word.
    func testAllDayLabelChoice() {
        let size = AllDayBandMetrics.labelPoints
        let font = UIFont.systemFont(ofSize: size)
        for language in languages {
            let full = L.text("allday.label", in: language)
            let short = L.text("allday.label.short", in: language)
            XCTAssertLessThanOrEqual(width(short, font) / size, 2.4, "the short form of \(language): \(short)")
            for (kind, gutter) in [(PageKind.week, PaperSpec.weekGutter), (PageKind.day, PaperSpec.dayGutter)] {
                let paper = ZoomPolicy.paperWidth(kind)
                let zooms: [(String, CGFloat, Bool)] = [
                    ("iPhone at full width", 402 / paper, false),
                    ("the readable zoom", ZoomPolicy.readableZoom(kind), true),
                    ("iPad in portrait", 1024 / paper, true),
                ]
                for (name, zoom, mustShow) in zooms {
                    let points = gutter * zoom
                    let label = PaperWords.allDayLabel(widthPoints: points, fontSize: size, language)
                    let what = "\(language) \(kind) \(name)"
                    if language == .ja {
                        XCTAssertEqual(label, "終日", "\(what): 1.1's path, also where the gutter cuts it")
                        continue
                    }
                    if mustShow {
                        XCTAssertNotNil(label, what)
                    }
                    if let label = label {
                        XCTAssertTrue(label == full || label == short, what)
                        XCTAssertLessThanOrEqual(width(label, font), points - PaperWords.allDayLabelPad, what)
                    } else {
                        XCTAssertGreaterThan(width(short, font), points - PaperWords.allDayLabelPad, what)
                    }
                }
                // The PDF: 11 pt in the gutter of 1 lu = 1 pt (58 and 66 pt of room).
                let pdfFont = UIFont.systemFont(ofSize: PDFPageRenderer.gutterFontSize)
                let label = PaperWords.allDayLabel(widthPoints: gutter, fontSize: PDFPageRenderer.gutterFontSize, language)
                XCTAssertLessThanOrEqual(width(label ?? "", pdfFont), gutter - PaperWords.allDayLabelPad, "\(language) \(kind) PDF")
                XCTAssertNotNil(label, "\(language) \(kind) PDF")
            }
        }
    }

    /// F-8: the weekday row of an iPhone's overview (57.4 pt columns, `.caption` semibold).
    func testMonthHeaderWeekdaysFit() {
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let column = PaperSpec.monthColumnWidth * 402 / PaperSpec.monthWidth
        XCTAssertEqual(column, 57.4, accuracy: 0.1)
        for language in languages {
            for weekStart in WeekStart.allCases {
                let names = PaperWords.monthHeaderWeekdays(language, weekStart: weekStart)
                XCTAssertEqual(names.count, 7)
                for name in names {
                    XCTAssertFalse(name.isEmpty)
                    XCTAssertLessThanOrEqual(width(name, font), column, "\(language): \(name)")
                }
            }
        }
    }

    /// F-9, docs/M7B.md FIX3: a week column's heading. A language with three-letter signs (pt-BR) has them
    /// over the number, all seven at 12 pt, the heavier today's too, in every column an iPhone or an iPad can
    /// have (a small iPhone's opening zoom gives about 40 pt, an iPhone 17 53.7 pt in the CI's photo); the
    /// number's box fits there too. A language with shorter signs stays beside the number, as in 1.1: there
    /// the sign shrinks on its own down to 0.6, and it must not end in 「…」 in an iPhone 17's column.
    func testWeekColumnWeekdaysFit() {
        let number = width("28", UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)) + 2 * 6
        for language in languages {
            let stacks = PaperWords.weekColumnStacksWeekday(language)
            XCTAssertEqual(stacks, language == .ptBR, "\(language)")
            if stacks {
                for column in [40, 50, 53.7, 74.9, 75, 101, 139] as [CGFloat] {
                    let room = column - 2 * 2
                    XCTAssertLessThanOrEqual(number, room + 0.05, "the number's box in \(column) pt")
                    for weekday in 0..<7 {
                        let sign = PaperWords.weekColumnWeekday(weekday, columnWidth: column, language)
                        for weight in [UIFont.Weight.medium, .bold] {
                            XCTAssertLessThanOrEqual(width(sign, UIFont.systemFont(ofSize: 12, weight: weight)), room, "\(language) \(sign) in \(column) pt is cut or shrinks alone")
                        }
                    }
                }
            } else {
                let room = 53 - 2 * 2 - 4 - 30 as CGFloat
                for weekday in 0..<7 {
                    let sign = PaperWords.weekColumnWeekday(weekday, columnWidth: 53, language)
                    XCTAssertLessThanOrEqual(width(sign, UIFont.systemFont(ofSize: 12 * 0.6, weight: .bold)), room, "\(language) \(sign) at 0.6 beside the number")
                }
            }
        }
        // pt-BR's own signs: every column has them whole, in the contract's form (§3.3).
        XCTAssertEqual((0..<7).map { PaperWords.weekColumnWeekday($0, columnWidth: 53.7, .ptBR) }, ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"])
        XCTAssertFalse(PaperWords.weekColumnStacksWeekday(.ja), "ja: 1.1's row (J-4)")
    }

    /// F-9: outside ja a holiday's full name that does not fit a week column gives way to the short name;
    /// ja keeps 1.1's one text.
    func testWeekColumnShortHoliday() {
        func label(_ full: String?, _ short: String?) -> DateLabel {
            DateLabel(day: DayKey(year: 2026, month: 10, day: 9), frame: .zero, isToday: false, inMonth: true, tone: .sundayOrHoliday, holidayName: full, holidayShortName: short)
        }
        XCTAssertEqual(PaperWords.weekColumnShortHoliday(label("國慶日（補假）", "國慶日"), .zhHant), "國慶日")
        XCTAssertNil(PaperWords.weekColumnShortHoliday(label("國慶日（補假）", "國慶日"), .ja), "ja: 1.1's path")
        XCTAssertNil(PaperWords.weekColumnShortHoliday(label("スポーツの日", "スポーツの日"), .ja))
        XCTAssertNil(PaperWords.weekColumnShortHoliday(label("Columbus Day", "Columbus Day"), .en), "nothing to fall back on")
        XCTAssertNil(PaperWords.weekColumnShortHoliday(label("Columbus Day", nil), .en))
        XCTAssertNil(PaperWords.weekColumnShortHoliday(label("Columbus Day", ""), .en))
    }

    /// A day heading as the screen draws it, in `language`, with the day's column `column` pt wide.
    private func dayHeading(holiday: String?, column: CGFloat, language: UILanguage) -> UIImage? {
        var layout = DayLayoutEngine.layout(DayLayoutInput(day: DayKey(year: 2026, month: 10, day: 7), events: [], inkBottoms: [:], now: now))
        layout.dateLabels[0].holidayName = holiday
        layout.dateLabels[0].tone = .normal // the number stays black: only the name counts as red below
        layout.dateLabels[0].isToday = false
        let zoom = column / (PaperSpec.dayTimelineRight - PaperSpec.dayGutter)
        let viewport = PaperViewport(offsetX: 0, zoom: zoom, width: PaperSpec.dayWidth * zoom)
        let header = StickyHeaderView(paper: .day(DayPaperContent(layout: layout)), now: now, viewport: viewport, language: language, onDayTap: { _ in }, onMonthTap: { _ in })
        let renderer = ImageRenderer(content: header.frame(width: viewport.width))
        renderer.scale = 2
        return renderer.uiImage
    }

    /// How many pixels of a picture are clearly the paper's red (`PaperPalette.red`, #dc2626).
    private func redPixels(_ image: UIImage?) -> Int {
        guard let cg = image?.cgImage else { return 0 }
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        var count = 0
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i] > 170 && bytes[i + 1] < 120 && bytes[i + 2] < 120 {
            count += 1
        }
        return count
    }

    /// F-10, docs/M7B.md FIX4: in the column of the CI's 6.9-inch photo (151.3 pt) and of the iPhone 17's
    /// (131.3 pt, both measured on the photos of the day page) a holiday's name is read whole: in the capsule
    /// when the whole row fits, else in the line of the month's name, and a long name in two small lines. The
    /// heading is as high as with no holiday. The zh-Hans photo had 「…」 here (`layoutPriority(-1)`) and no
    /// other place on the page has the name. The form is `ViewThatFits`'s: the picture says the name is there.
    func testDayHeadingNameIsReadInAnIPhoneColumn() {
        let names: [(UILanguage, String)] = [
            (.zhHans, "休息日"), (.zhHant, "國慶日"), (.ko, "개천절"), (.en, "Columbus Day"), (.fr, "Toussaint"),
            (.de, "Neujahr"), (.es, "Año Nuevo"), (.it, "Ognissanti"), (.ptBR, "Finados"),
            // Long ones: two lines (the longest of all lose their end to 「…」, as below).
            (.zhHant, "中華民國開國紀念日"), (.ko, "부처님오신날 대체 휴일"), (.en, "Martin Luther King Jr. Day"), (.fr, "Lundi de Pentecôte"),
            (.de, "Tag der Deutschen Einheit"), (.es, "Natalicio de Benito Juárez"), (.it, "Anniversario della Liberazione"), (.ptBR, "Nossa Senhora Aparecida"),
        ]
        let day = DayKey(year: 2026, month: 10, day: 7)
        let numberFont = UIFont.monospacedDigitSystemFont(ofSize: 21, weight: .semibold)
        for (language, name) in names {
            let number = max(36, width("7", numberFont) + 2 * 6)
            let lines = max(width(DateText.monthName(day.month, .full, language), UIFont.systemFont(ofSize: 11)),
                            width(DateText.weekdays(.full, language)[day.weekday], UIFont.systemFont(ofSize: 14, weight: .semibold)))
            let capsule = width(name, UIFont.systemFont(ofSize: 12)) + 2 * 8
            for column in [131.3, 151.3] as [CGFloat] {
                let plain = dayHeading(holiday: nil, column: column, language: language)
                let named = dayHeading(holiday: name, column: column, language: language)
                XCTAssertEqual(named?.size.height ?? 0, plain?.size.height ?? 1, accuracy: 0.01, "\(language) \(name) \(column) pt: the heading's height (K-6)")
                XCTAssertEqual(plain?.size.height ?? 0, 52, accuracy: 0.5, "\(language) \(column) pt: minHeight 52")
                // The name itself, at the smallest it has here, against what is on the heading: 「…」 is far less.
                let renderer = ImageRenderer(content: Text(name).font(.system(size: PaperWords.dayHeadingLongHolidayPoints)).foregroundStyle(Color(uiColor: PaperPalette.red)))
                renderer.scale = 2
                let whole = redPixels(renderer.uiImage)
                XCTAssertGreaterThan(whole, 0, "\(language): the reference")
                XCTAssertGreaterThanOrEqual(Double(redPixels(named)), 0.7 * Double(whole), "\(language) \(name) in \(column) pt: the name is not on the heading")
            }
            // A wide column keeps the capsule where the whole row fits (an iPad's 273 pt in the 13-inch photo).
            let wide = dayHeading(holiday: name, column: 273, language: language)
            XCTAssertEqual(wide?.size.height ?? 0, dayHeading(holiday: nil, column: 273, language: language)?.size.height ?? 1, accuracy: 0.01, "\(language) \(name) on an iPad")
            if capsule < 100 {
                XCTAssertLessThanOrEqual(number + 10 + lines + 10 + capsule, 273 - 2 * 12, "\(language) \(name) on an iPad: the capsule")
            }
        }
        // All the forms in one pinch: from an iPhone's column up to a readable one, the same height.
        for column in [131.3, 151.3, 200, 250, 330] as [CGFloat] {
            XCTAssertEqual(dayHeading(holiday: "Nossa Senhora Aparecida", column: column, language: .ptBR)?.size.height ?? 0,
                           dayHeading(holiday: nil, column: 151.3, language: .ptBR)?.size.height ?? 1, accuracy: 0.01, "\(column) pt")
        }
        // Far too long for two lines: cut, and still the same height.
        XCTAssertEqual(dayHeading(holiday: "臺灣光復暨金門古寧頭大捷紀念日（補假）", column: 131.3, language: .zhHant)?.size.height ?? 0, 52, accuracy: 0.5)
        XCTAssertEqual(dayHeading(holiday: "Festa nazionale di San Francesco d'Assisi, patrono d'Italia", column: 131.3, language: .it)?.size.height ?? 0, 52, accuracy: 0.5)
    }

    /// F-8: ja is 1.1's 「n月」, shrinking on its own; the others have one scale for the twelve, and
    /// numbers below 0.7.
    func testYearMonthTitlesScale() {
        let size = StickyHeaderView.yearMonthFontSize
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        for column in [8, 32, 150] as [CGFloat] {
            let japanese = PaperWords.yearColumnTitles(columnWidth: column, fontSize: size, .ja)
            XCTAssertEqual(japanese.titles, (1...12).map { "\($0)月" })
            XCTAssertNil(japanese.scale, "ja: each month down to 0.7, as in 1.1")
        }
        for language in languages where language != .ja {
            let names = (1...12).map { DateText.monthName($0, .short, language) }
            let widest = names.map { width($0, font) }.max() ?? 0
            XCTAssertGreaterThan(widest, 0)

            let wide = PaperWords.yearColumnTitles(columnWidth: widest + 4 + 1, fontSize: size, language)
            XCTAssertEqual(wide.titles, names, "\(language) in a wide column")
            XCTAssertEqual(wide.scale ?? 0, 1, accuracy: 0.0001, "\(language) in a wide column")

            let fitted = PaperWords.yearColumnTitles(columnWidth: widest * 0.8 + 4, fontSize: size, language)
            XCTAssertEqual(fitted.titles, names, "\(language) at 0.8")
            XCTAssertEqual(fitted.scale ?? 0, 0.8, accuracy: 0.001, "\(language) at 0.8")

            let numbers = PaperWords.yearColumnTitles(columnWidth: widest * 0.6 + 4, fontSize: size, language)
            XCTAssertEqual(numbers.titles, (1...12).map { String($0) }, "\(language) below 0.7")
            XCTAssertEqual(numbers.scale ?? 0, 1, accuracy: 0.0001, "\(language) below 0.7")
        }
    }

    /// ja goes the way 1.1 went: the boxes, `drawLine` and the modifiers of 1.1 (the heading of §4.1). That
    /// the pictures are the same is J-4's comparison of the photos.
    func testJapaneseTakesTheOneOnePath() {
        let frame = CGRect(x: 168, y: 120, width: 40, height: 28)
        let pad = PaperSpec.yearPad
        let em = PaperText.yearWeekday.lu

        // F-1: the signs in 1.1's box with 1.1's drawLine; the number's box ends where 1.1's did.
        XCTAssertEqual(YearPaper.weekdayBoxWidth(weekdaySize: em, pad: pad, .ja), em * 1.4, accuracy: 0.0001)
        XCTAssertNil(PaperWords.yearWeekdayScale(boxWidth: em * 1.4, fontSize: em, .ja))
        XCTAssertEqual((0..<7).map { PaperWords.yearWeekday($0, .ja) }, ["日", "月", "火", "水", "木", "金", "土"])
        let plain = YearPaper.numberRect(frame: frame, pad: pad, weekdaySize: em, lineHeight: 18, isToday: false)
        XCTAssertEqual(plain, CGRect(x: frame.minX + pad, y: frame.minY + pad, width: em * 1.3, height: 18), "1.1's box")
        let today = YearPaper.numberRect(frame: frame, pad: pad, weekdaySize: em, lineHeight: 18, isToday: true)
        XCTAssertEqual(today.maxX, frame.minX + pad + 1.3 * em, accuracy: 0.0001, "the right edge is 1.1's")
        XCTAssertEqual(today.minX, frame.minX + pad - 0.1 * em, accuracy: 0.0001, "0.1 em wider to the left")
        XCTAssertGreaterThan(today.minX, frame.minX + 1, "clear of today's ring")
        // What the simulator measures, for the record (docs/M7B.md, P): both are 2 digits of a monospaced font.
        print("repro: F-1 two digits at \(em) lu: semibold \(width("28", UIFont.monospacedDigitSystemFont(ofSize: em, weight: .semibold))) in \(plain.width), heavy \(width("31", UIFont.monospacedDigitSystemFont(ofSize: em, weight: .heavy))) in \(today.width)")

        // F-2, F-3: drawLine; the other languages shrink.
        XCTAssertEqual(PaperWords.yearHolidayFit(.ja), .oneOne)
        XCTAssertEqual(PaperWords.monthHolidayFit(.ja), .oneOne)
        for language in languages where language != .ja {
            XCTAssertEqual(PaperWords.yearHolidayFit(language), .fitted(minScale: 0.8))
            XCTAssertEqual(PaperWords.monthHolidayFit(language), .fitted(minScale: 0.9))
        }

        // F-7: 「終日」 whatever the width.
        for points in [1, 18.4, 64] as [CGFloat] {
            XCTAssertEqual(PaperWords.allDayLabel(widthPoints: points, fontSize: 10, .ja), "終日")
        }

        // F-8.
        XCTAssertEqual(PaperWords.monthHeaderWeekdays(.ja, weekStart: .monday), ["月", "火", "水", "木", "金", "土", "日"])
        XCTAssertNil(PaperWords.yearColumnTitles(columnWidth: 150, fontSize: 13, .ja).scale)

        // F-9: one character in every column, beside the number.
        for column in [10, 74, 75, 300] as [CGFloat] {
            XCTAssertEqual((0..<7).map { PaperWords.weekColumnWeekday($0, columnWidth: column, .ja) }, ["日", "月", "火", "水", "木", "金", "土"])
        }
        XCTAssertFalse(PaperWords.weekColumnStacksWeekday(.ja))

        // F-10: the values SwiftUI has without the modifiers.
        let fit = PaperWords.dayHeadingFit(.ja)
        XCTAssertNil(fit.lineLimit)
        XCTAssertEqual(fit.minScale, 1)
        XCTAssertEqual(fit.holidayPriority, 0)
        XCTAssertEqual(DateText.monthName(10, .full, .ja), "10月")
        XCTAssertEqual(DateText.weekdays(.full, .ja)[3], "水曜日")
        let other = PaperWords.dayHeadingFit(.de)
        XCTAssertEqual(other.lineLimit, 1)
        XCTAssertEqual(other.minScale, 0.8, accuracy: 0.0001)
        XCTAssertEqual(other.holidayPriority, -1)
        // F-10 (FIX4): ja has the one row, whatever the holiday and the column; the others can have the name on top.
        let holiday = DateLabel(day: DayKey(year: 2026, month: 10, day: 12), frame: .zero, isToday: false, inMonth: true, tone: .sundayOrHoliday, holidayName: "スポーツの日")
        XCTAssertNil(PaperWords.dayHeadingHolidayLine(holiday, .ja), "ja: 1.1's HStack and modifiers")
        XCTAssertEqual(PaperWords.dayHeadingHolidayLine(holiday, .de), "スポーツの日")
        var noHoliday = holiday
        noHoliday.holidayName = nil
        XCTAssertNil(PaperWords.dayHeadingHolidayLine(noHoliday, .de))
        noHoliday.holidayName = ""
        XCTAssertNil(PaperWords.dayHeadingHolidayLine(noHoliday, .de))

        // F-11: one text.
        XCTAssertNil(PageHeaderView.titleParts("2026年11月3日(火) 文化の日", holiday: "文化の日", language: .ja))
    }

    /// F-16: the switch's four words at 13 pt semibold within 44 pt, 「今日」 at 17 pt within ja's width + 16 pt.
    /// The 44 pt is a guide (the room in a segment cannot be measured here, the contract says), with half a
    /// point of slack for the measuring: de 「Woche」, which the contract lets in at 43.7 pt, is 44.2 on a Mac.
    /// 「今日」 has the same half point: de 「Heute」 is within 0.005 pt of the limit on a Mac. It never clips
    /// (`fixedSize`); what narrows is the title.
    func testHeaderPickerAndTodayFit() {
        let pickerFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let todayFont = UIFont.systemFont(ofSize: 17)
        let todayLimit = width(L.text("header.today", in: .ja), todayFont) + 16.5
        for language in languages {
            for key in ["header.picker.day", "header.picker.week", "header.picker.month", "header.picker.year"] {
                let text = L.text(key, in: language)
                XCTAssertLessThanOrEqual(width(text, pickerFont), 44.5, "\(key) in \(language): \(text)")
            }
            let today = L.text("header.today", in: language)
            XCTAssertLessThanOrEqual(width(today, todayFont), todayLimit, "header.today in \(language): \(today)")
        }
    }

    // MARK: - §10.8

    /// §10.5: the order is the layout's first row, and the colour goes with the weekday.
    func testMonthHeaderOrderAndColors() {
        let sundayFirst = month(.sunday)
        let mondayFirst = month(.monday)
        XCTAssertEqual(sundayFirst.rows[0].days[0].weekday, 0)
        XCTAssertEqual(mondayFirst.rows[0].days[0].weekday, 1)
        for language in languages {
            let sunday = PaperWords.monthHeaderColumns(sundayFirst, language)
            XCTAssertEqual(sunday.map(\.weekday), [0, 1, 2, 3, 4, 5, 6], "\(language)")
            XCTAssertEqual(sunday.map(\.name), PaperWords.monthHeaderWeekdays(language, weekStart: .sunday), "\(language)")
            XCTAssertEqual(sunday.map(\.tone), [.sundayOrHoliday, .normal, .normal, .normal, .normal, .normal, .saturday], "\(language): Sunday red in column 0, Saturday blue in column 6")

            let monday = PaperWords.monthHeaderColumns(mondayFirst, language)
            XCTAssertEqual(monday.map(\.weekday), [1, 2, 3, 4, 5, 6, 0], "\(language)")
            XCTAssertEqual(monday.map(\.name), PaperWords.monthHeaderWeekdays(language, weekStart: .monday), "\(language)")
            XCTAssertEqual(monday.map(\.tone), [.normal, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday], "\(language): 1.1's colours")

            XCTAssertEqual(sunday.map(\.fullName), DateText.weekdays(.full, language), "\(language): spoken, §4.2")
        }
        XCTAssertEqual(PaperWords.monthHeaderColumns(sundayFirst, .ja).map(\.name).joined(), "日月火水木金土")
        XCTAssertEqual(PaperWords.monthHeaderColumns(mondayFirst, .ja).map(\.name).joined(), "月火水木金土日")
        XCTAssertEqual(PaperPalette.toneColor(.sundayOrHoliday), PaperPalette.red)
        XCTAssertEqual(PaperPalette.toneColor(.saturday), PaperPalette.blue)
        XCTAssertEqual(PaperPalette.toneColor(.normal), PaperPalette.ink1)
    }

    // MARK: - F-0

    /// RGBA bytes of one line drawn on white.
    private func picture(size: CGSize, _ draw: () -> Void) -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            draw()
        }
        guard let cg = image.cgImage else { return [] }
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }

    /// F-0: a text that fits is `drawLine`'s picture, pixel for pixel; a text that does not is smaller,
    /// not below the floor; a given scale is used as it is.
    func testFittedLineIsTheSameWhenItFits() {
        let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let rect = CGRect(x: 2, y: 2, width: 120, height: 22)
        let plain = picture(size: CGSize(width: 124, height: 26)) {
            PaperText.drawLine("Thanksgiving", in: rect, font: font, color: PaperPalette.red)
        }
        let fitted = picture(size: CGSize(width: 124, height: 26)) {
            PaperText.drawFittedLine("Thanksgiving", in: rect, font: font, color: PaperPalette.red, minScale: 0.8)
        }
        XCTAssertFalse(plain.isEmpty)
        XCTAssertEqual(plain, fitted, "a text that fits is the same picture")

        XCTAssertEqual(PaperText.fittedScale(of: "Thanksgiving", width: 120, font: font, minScale: 0.8), 1)
        let natural = PaperText.naturalWidth(of: "Thanksgiving", font: font)
        let shrunk = PaperText.fittedScale(of: "Thanksgiving", width: natural * 0.9, font: font, minScale: 0.8)
        XCTAssertEqual(shrunk, 0.9, accuracy: 0.05, "about the ratio, less for the font's tracking at the smaller size")
        XCTAssertLessThan(shrunk, 1)
        XCTAssertLessThanOrEqual(PaperText.naturalWidth(of: "Thanksgiving", font: font.withSize(15 * shrunk)), natural * 0.9)
        XCTAssertEqual(PaperText.fittedScale(of: "Thanksgiving", width: natural * 0.5, font: font, minScale: 0.8), 0.8, "the floor")

        let narrow = CGRect(x: 2, y: 2, width: natural * 0.9, height: 22)
        let shrunkPicture = picture(size: CGSize(width: 124, height: 26)) {
            PaperText.drawFittedLine("Thanksgiving", in: narrow, font: font, color: PaperPalette.red, minScale: 0.8)
        }
        let cutPicture = picture(size: CGSize(width: 124, height: 26)) {
            PaperText.drawLine("Thanksgiving", in: narrow, font: font, color: PaperPalette.red)
        }
        XCTAssertNotEqual(shrunkPicture, cutPicture, "smaller, not cut")
    }

    // MARK: - J-1: the composed Japanese sentences (§2.4)

    func testComposedJapaneseIsTheOneOneText() {
        XCTAssertEqual(L.language, .ja, "these tests run in Japanese (0-25)")
        let expected: [(PageKind, String)] = [(.day, "日"), (.week, "週"), (.month, "月"), (.year, "年")]
        for (kind, word) in expected {
            XCTAssertEqual(PageHeaderView.shortLabel(kind), word)
            XCTAssertEqual(PageHeaderView.pickerItemLabel(kind), word + "表示")
            XCTAssertEqual(PageHeaderView.previousLabel(kind), "前の" + word)
            XCTAssertEqual(PageHeaderView.nextLabel(kind), "次の" + word)
        }
        XCTAssertEqual(PageHeaderView.syncLabel(HeaderSync(text: "保存済み", symbol: "icloud", isError: false)), "同期: 保存済み")
        XCTAssertEqual(PageHeaderView.readOnlyLabel, "閲覧専用。購読の案内を開く")
        XCTAssertEqual(L.text("header.today"), "今日")
        XCTAssertEqual(L.text("header.addEvent"), "予定")
        XCTAssertEqual(L.text("header.addEvent.spoken"), "予定を追加")
        XCTAssertEqual(L.text("header.settings.spoken"), "設定")
        XCTAssertEqual(L.text("header.picker.spoken"), "表示の切替")

        let day = DayKey(year: 2026, month: 10, day: 7)
        let label = DateLabel(day: day, frame: .zero, isToday: false, inMonth: true, tone: .normal, holidayName: nil)
        XCTAssertEqual(StickyHeaderView.dayLabel(label), "2026年10月7日(水)")
        XCTAssertEqual(L.format("header.day.spoken", StickyHeaderView.dayLabel(label)), "2026年10月7日(水)（日表示へ）")
        var holiday = label
        holiday.holidayName = "体育の日"
        XCTAssertEqual(StickyHeaderView.dayLabel(holiday), "2026年10月7日(水) 体育の日")
        XCTAssertEqual(StickyHeaderView.dayLabel(holiday, language: .en).hasSuffix(", 体育の日"), true, "§4.2")
        XCTAssertEqual(L.format("header.month.spoken", YearMonth(year: 2026, month: 3).title(language: .ja)), "2026年3月（月表示へ）")

        XCTAssertEqual(AllDayBandView.columnLabel(day), "2026年10月7日(水) の終日予定を追加")
        let bar = AllDayBandBar(eventId: "e", title: "遠足", colorHex: "#2563eb", lane: 0, startCol: 0, endCol: 0, continuesLeft: false, continuesRight: false, minX: 0, maxX: 10)
        XCTAssertEqual(AllDayBandView.barLabel(bar), "遠足（予定を編集）")

        XCTAssertEqual(LayoutWords.of(.ja).more(3), "+3件")
        XCTAssertEqual(L.text("paper.memo"), "メモ")
        XCTAssertEqual(DayPaper.freeMemoLabel, "自由メモ")
        XCTAssertEqual(PDFPageRenderer.creator, "てがきカレンダー")
        XCTAssertEqual(L.text("allday.label"), "終日")
        XCTAssertEqual((1...12).map { DateText.monthName($0, .full, .ja) }, (1...12).map { "\($0)月" })
    }

    // MARK: - F-11

    func testTitlePartsSplitTheHolidayOff() {
        let parts = PageHeaderView.titleParts("Thu, November 26, 2026 Thanksgiving Day", holiday: "Thanksgiving Day", language: .en)
        XCTAssertEqual(parts?.date, "Thu, November 26, 2026")
        XCTAssertEqual(parts?.holiday, "Thanksgiving Day")
        XCTAssertNil(PageHeaderView.titleParts("Thu, Nov 26", holiday: "Thanksgiving Day", language: .en), "the compact title has no holiday")
        XCTAssertNil(PageHeaderView.titleParts("Thu, November 26, 2026", holiday: nil, language: .en))
        XCTAssertNil(PageHeaderView.titleParts("Thu, November 26, 2026", holiday: "", language: .en))
    }
}
