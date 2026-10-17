import InkModel
import Layout
import UIKit

/// The PDF of one page (M6_CONTRACT §1.4, §2.3, D1 (b)): the page the screen is showing — its
/// `PaperContent` and `InkPage` as they are, no re-layout — on one PDF page at zoom 1 (1 lu = 1 pt).
/// The paper, the events and the holidays go through the same renderers as the screen
/// (`MonthPaper` … `YearPaper`, vectors with embedded fonts); the handwriting is PencilKit's own
/// picture (`InkSnapshot.image`, a 2x raster, 0-5: PencilKit has no vector output). The heading —
/// the title, the weekday / date / month-name row and the all-day band, which the screen draws as
/// SwiftUI views outside the paper (`StickyHeaderView`, `AllDayBandView`) — is drawn here (0-9).
/// The current-time line is left out (`stripNowLine`, 0-13 / M6-23); the 「今日」 tints stay.
@MainActor
enum PDFPageRenderer {
    /// Pixels per point of the handwriting picture (2x; `InkSnapshot` lowers it on its own when the
    /// paper is so tall that 2x would exceed its 12M-pixel limit, 0-5).
    static let inkScale: CGFloat = 2
    /// The title row (「2026年10月」, 20 pt semibold).
    static let titleHeight: CGFloat = 36
    /// The month's weekday row and the year's month-name row.
    static let labelRowHeight: CGFloat = 28
    /// The week's and day's date row.
    static let dateRowHeight: CGFloat = 40
    /// Below the band's last lane (the lanes start `bandPad / 2` under the band's top).
    static let bandPad: CGFloat = 6
    static let creator = "てがきカレンダー"

    static let titleFontSize: CGFloat = 20
    static let labelFontSize: CGFloat = 14
    static let holidayFontSize: CGFloat = 10
    static let barFontSize: CGFloat = 12
    static let gutterFontSize: CGFloat = 11
    static let titleInset: CGFloat = 16
    static let barCorner: CGFloat = 4
    static let barTextPad: CGFloat = 6
    private static let monthWeekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    /// The distance between two all-day lanes: `.week` → `PaperSpec.allDayLaneStep` (25), `.day` →
    /// `PaperSpec.dayLaneStep` (24); the month and year pages have no band → 0.
    static func laneStep(_ kind: PageKind) -> CGFloat {
        switch kind {
        case .week: return PaperSpec.allDayLaneStep
        case .day: return PaperSpec.dayLaneStep
        case .month, .year: return 0
        }
    }

    // MARK: - Geometry (§1.4)

    /// The part of the paper that goes on the page, in paper units from the paper's origin. Month:
    /// the whole paper (6 rows + the memo area) when the memo area holds handwriting, else the
    /// overview rectangle (1400 × `memo.minY`, `ZoomPolicy.overviewSize`; 0-3 / M6-3). Week, day and
    /// year: the whole paper (`layout.size`).
    static func paperRect(_ paper: PaperContent, page: InkPage) -> CGRect {
        switch paper {
        case .month(let content):
            let memoHasInk = page.liveStrokes.contains { $0.cell.isMemo }
            let size = memoHasInk ? content.layout.size : ZoomPolicy.overviewSize(content.layout)
            return CGRect(origin: .zero, size: size)
        case .week, .day, .year:
            return CGRect(origin: .zero, size: paper.layout.size)
        }
    }

    /// Height of the heading above the paper: the title row + the page's own row (month: the
    /// weekday row; week / day: the date row + the all-day band `laneCount × laneStep + bandPad`, 0
    /// without a lane; year: the month-name row).
    static func headingHeight(_ paper: PaperContent) -> CGFloat {
        switch paper {
        case .month, .year:
            return titleHeight + labelRowHeight
        case .week, .day:
            return titleHeight + dateRowHeight + bandHeight(paper)
        }
    }

    /// `laneCount × laneStep(kind) + bandPad`; 0 without a lane (and on the month / year pages).
    static func bandHeight(_ paper: PaperContent) -> CGFloat {
        guard let band = paper.allDayBand, band.laneCount > 0 else { return 0 }
        return CGFloat(band.laneCount) * laneStep(paper.kind) + bandPad
    }

    /// The PDF page: as wide as the paper, `headingHeight + paperRect.height` tall, no margins.
    static func pageSize(_ paper: PaperContent, page: InkPage) -> CGSize {
        let rect = paperRect(paper, page: page)
        return CGSize(width: rect.width, height: headingHeight(paper) + rect.height)
    }

    /// The week / day content with `layout.nowLine = nil` (a copy of the value-type layout, not a
    /// re-layout: everything else stays as on the screen); the month and year content as they are
    /// (their `nowLine` is always nil). Pure function (0-13, M6-23).
    static func stripNowLine(_ paper: PaperContent) -> PaperContent {
        switch paper {
        case .week(var content):
            content.layout.nowLine = nil
            return .week(content)
        case .day(var content):
            content.layout.nowLine = nil
            return .day(content)
        case .month, .year:
            return paper
        }
    }

    // MARK: - Rendering

    /// One PDF page of `paper` with the handwriting of `page`, titled `title` (`kCGPDFContextTitle`;
    /// the creator is `creator`). Order: the whole page in `PaperPalette.paper` → the heading → the
    /// paper through the page kind's `PaperRenderer` (zoom 1, a dummy `PaperView` whose
    /// `contentScaleFactor` is 2 for the hairline snapping, 0-4) → the handwriting picture, when
    /// there is one. Empty `Data` means the renderer failed (`ExportBuilder` turns it into
    /// `ExportError.renderFailed`).
    static func render(_ paper: PaperContent, page: InkPage, title: String) -> Data {
        let paper = stripNowLine(paper)
        let rect = paperRect(paper, page: page)
        let heading = headingHeight(paper)
        let size = pageSize(paper, page: page)
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return Data() }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: creator,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size), format: format)
        let dummy = PaperView(content: paper)
        dummy.contentScaleFactor = inkScale

        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext
            ctx.setFillColor(PaperPalette.paper.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            drawHeading(paper, in: ctx, width: size.width, title: title)

            ctx.saveGState()
            ctx.translateBy(x: 0, y: heading)
            ctx.clip(to: rect)
            switch paper {
            case .month(let content):
                MonthPaper.draw(content, in: ctx, dirty: rect, zoom: 1, view: dummy)
            case .week(let content):
                WeekPaper.draw(content, in: ctx, dirty: rect, zoom: 1, view: dummy)
            case .day(let content):
                DayPaper.draw(content, in: ctx, dirty: rect, zoom: 1, view: dummy)
            case .year(let content):
                YearPaper.draw(content, in: ctx, dirty: rect, zoom: 1, view: dummy)
            }
            if let image = InkSnapshot.image(strokes: page.liveStrokes, cells: paper.layout.cells, bounds: rect, zoom: 1, scale: inkScale) {
                image.draw(in: rect)
            }
            ctx.restoreGState()
        }
    }

    // MARK: - Heading (§1.4: the title row, the page's row, the all-day band)

    private static func drawHeading(_ paper: PaperContent, in ctx: CGContext, width: CGFloat, title: String) {
        let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .semibold)
        PaperText.drawLine(title, in: CGRect(x: titleInset, y: 0, width: max(0, width - 2 * titleInset), height: titleHeight),
                           font: titleFont, color: PaperPalette.ink1)
        let top = titleHeight
        switch paper {
        case .month:
            drawMonthWeekdayRow(ctx, top: top, width: width)
        case .week(let content):
            drawWeekDateRow(ctx, layout: content.layout, top: top, width: width)
            drawBand(ctx, paper: paper, top: top + dateRowHeight, width: width)
        case .day(let content):
            drawDayDateRow(ctx, layout: content.layout, top: top, width: width)
            drawBand(ctx, paper: paper, top: top + dateRowHeight, width: width)
        case .year(let content):
            drawYearMonthRow(ctx, content: content, top: top, width: width)
        }
    }

    /// 月 火 水 木 金 土 日 centred over the 7 columns (200 lu), Saturday blue, Sunday red.
    private static func drawMonthWeekdayRow(_ ctx: CGContext, top: CGFloat, width: CGFloat) {
        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        for column in 0..<PaperSpec.monthColumns {
            let color: UIColor
            switch column {
            case 5: color = PaperPalette.blue
            case 6: color = PaperPalette.red
            default: color = PaperPalette.ink1
            }
            let rect = CGRect(x: CGFloat(column) * PaperSpec.monthColumnWidth, y: top, width: PaperSpec.monthColumnWidth, height: labelRowHeight)
            PaperText.drawLine(monthWeekdayLabels[column], in: rect, font: font, color: color, alignment: .center)
        }
        horizontalLine(ctx, y: top + labelRowHeight, from: 0, to: width, color: PaperPalette.line)
    }

    /// The 7 day headers of the week: the weekday letter and the day (「水 7」, 「10/1」 on the first
    /// of a month) 14 pt in the tone's colour, the holiday name 10 pt red under it; the column's
    /// today / weekend tint and its left line as on the screen.
    private static func drawWeekDateRow(_ ctx: CGContext, layout: WeekPageLayout, top: CGFloat, width: CGFloat) {
        let band = layout.allDayBand
        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        let holidayFont = UIFont.systemFont(ofSize: holidayFontSize, weight: .regular)
        for (index, label) in layout.dateLabels.enumerated() {
            let x = index < band.columnMinX.count ? band.columnMinX[index] : label.frame.minX
            let columnWidth = band.columnWidth > 0 ? band.columnWidth : label.frame.width
            let cell = CGRect(x: x, y: top, width: columnWidth, height: dateRowHeight)
            if let tint = columnTint(todayColumn: layout.todayColumn, index: index, tone: label.tone, soft: false) {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(cell)
            }
            verticalLine(ctx, x: x, from: top, to: top + dateRowHeight, color: PaperPalette.line)
            let number = label.day.day == 1 ? "\(label.day.month)/1" : "\(label.day.day)"
            let text = PageNavigation.weekdayLetters[max(0, min(6, label.day.weekday))] + " " + number
            let color = PaperPalette.toneColor(label.tone)
            if let holiday = label.holidayName, !holiday.isEmpty {
                PaperText.drawLine(text, in: CGRect(x: x, y: top + 4, width: columnWidth, height: 18), font: font, color: color, alignment: .center)
                PaperText.drawLine(holiday, in: CGRect(x: x, y: top + 22, width: columnWidth, height: 14), font: holidayFont,
                                   color: PaperPalette.red, alignment: .center)
            } else {
                PaperText.drawLine(text, in: cell, font: font, color: color, alignment: .center)
            }
        }
        horizontalLine(ctx, y: top + dateRowHeight, from: 0, to: width, color: PaperPalette.line)
    }

    /// The day's date row: the title already carries the date, so the row only keeps the timeline
    /// column's tint and the gutter / memo lines (the 「終日」 label sits in the band's gutter).
    private static func drawDayDateRow(_ ctx: CGContext, layout: DayPageLayout, top: CGFloat, width: CGFloat) {
        let timeline = CGRect(x: PaperSpec.dayGutter, y: top, width: PaperSpec.dayTimelineRight - PaperSpec.dayGutter, height: dateRowHeight)
        let tone = layout.dateLabels.first?.tone ?? .normal
        if let tint = columnTint(todayColumn: layout.isToday ? 0 : nil, index: 0, tone: tone, soft: true) {
            ctx.setFillColor(tint.cgColor)
            ctx.fill(timeline)
        }
        verticalLine(ctx, x: PaperSpec.dayGutter, from: top, to: top + dateRowHeight, color: PaperPalette.lineStrong)
        verticalLine(ctx, x: PaperSpec.dayTimelineRight, from: top, to: top + dateRowHeight, color: PaperPalette.lineStrong)
        horizontalLine(ctx, y: top + dateRowHeight, from: 0, to: width, color: PaperPalette.line)
    }

    /// 「1月」…「12月」 centred over the 12 columns (x = 56 + i × 112), this month's in the accent
    /// colour like the sticky header's, a strong line at every column's left edge.
    private static func drawYearMonthRow(_ ctx: CGContext, content: YearPaperContent, top: CGFloat, width: CGFloat) {
        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        let currentMonth = content.layout.todayCell?.yearMonthDay?.month
        for index in 0..<PaperSpec.yearColumns {
            let x = PaperSpec.yearGutter + CGFloat(index) * PaperSpec.yearColumnWidth
            verticalLine(ctx, x: x, from: top, to: top + labelRowHeight, color: PaperPalette.lineStrong)
            let name = index < content.monthNames.count ? content.monthNames[index] : "\(index + 1)月"
            let color = currentMonth == index + 1 ? PaperPalette.accent : PaperPalette.ink1
            PaperText.drawLine(name, in: CGRect(x: x, y: top, width: PaperSpec.yearColumnWidth, height: labelRowHeight),
                               font: font, color: color, alignment: .center)
        }
        horizontalLine(ctx, y: top + labelRowHeight, from: 0, to: width, color: PaperPalette.line)
    }

    /// The fixed all-day band (`AllDayBandLayout`, the same values as the screen's `AllDayBandView`):
    /// the column tints, 「終日」 in the gutter on the first lane, one rounded bar per event at
    /// `bar.minX … bar.maxX` (square on a side that continues past the range), lane `lane` at
    /// `bandPad / 2 + lane × laneStep(kind)`, 22 lu tall, its title in `PaperPalette.readableText`.
    /// Nothing without a lane.
    private static func drawBand(_ ctx: CGContext, paper: PaperContent, top: CGFloat, width: CGFloat) {
        guard let band = paper.allDayBand, band.laneCount > 0 else { return }
        let height = bandHeight(paper)
        let step = laneStep(paper.kind)
        let soft = paper.kind == .day
        for index in band.days.indices {
            let tone = index < band.tones.count ? band.tones[index] : .normal
            guard let tint = columnTint(todayColumn: band.todayColumn, index: index, tone: tone, soft: soft) else { continue }
            let x = index < band.columnMinX.count ? band.columnMinX[index] : 0
            ctx.setFillColor(tint.cgColor)
            ctx.fill(CGRect(x: x, y: top, width: band.columnWidth, height: height))
        }
        if paper.kind == .day {
            verticalLine(ctx, x: PaperSpec.dayGutter, from: top, to: top + height, color: PaperPalette.lineStrong)
            verticalLine(ctx, x: PaperSpec.dayTimelineRight, from: top, to: top + height, color: PaperPalette.lineStrong)
        }

        let laneTop = top + bandPad / 2
        let gutterFont = UIFont.systemFont(ofSize: gutterFontSize, weight: .regular)
        PaperText.drawLine("終日", in: CGRect(x: 0, y: laneTop, width: max(0, band.gutter - barTextPad), height: PaperSpec.allDayLane),
                           font: gutterFont, color: PaperPalette.ink3, alignment: .right)

        let barFont = UIFont.systemFont(ofSize: barFontSize, weight: .semibold)
        for bar in band.bars where bar.maxX > bar.minX {
            let frame = CGRect(x: bar.minX, y: laneTop + CGFloat(bar.lane) * step, width: bar.maxX - bar.minX, height: PaperSpec.allDayLane)
            let path = PaperText.roundedPath(frame, radius: barCorner, squareLeft: bar.continuesLeft, squareRight: bar.continuesRight)
            ctx.setFillColor(PaperPalette.color(hex: bar.colorHex).cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            let textRect = frame.insetBy(dx: barTextPad, dy: 0)
            guard textRect.width > barFontSize else { continue }
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            PaperText.drawLine(bar.title, in: textRect, font: barFont, color: PaperPalette.readableText(on: bar.colorHex))
            ctx.restoreGState()
        }
        horizontalLine(ctx, y: top + height, from: 0, to: width, color: PaperPalette.lineStrong)
    }

    // MARK: - Helpers

    /// Today wins (`todayTint`, the day page's `todayTintSoft`), then Saturday / Sunday / holiday
    /// (`weekendTint` / `weekendTintSoft`); nil for a plain weekday (the same rule as the paper's
    /// columns and the band view's).
    private static func columnTint(todayColumn: Int?, index: Int, tone: DayTone, soft: Bool) -> UIColor? {
        if todayColumn == index {
            return soft ? PaperPalette.todayTintSoft : PaperPalette.todayTint
        }
        guard tone != .normal else { return nil }
        return soft ? PaperPalette.weekendTintSoft : PaperPalette.weekendTint
    }

    private static func horizontalLine(_ ctx: CGContext, y: CGFloat, from x0: CGFloat, to x1: CGFloat, color: UIColor) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x0, y: y - 0.5))
        ctx.addLine(to: CGPoint(x: x1, y: y - 0.5))
        ctx.strokePath()
    }

    private static func verticalLine(_ ctx: CGContext, x: CGFloat, from y0: CGFloat, to y1: CGFloat, color: UIColor) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x + 0.5, y: y0))
        ctx.addLine(to: CGPoint(x: x + 0.5, y: y1))
        ctx.strokePath()
    }
}
