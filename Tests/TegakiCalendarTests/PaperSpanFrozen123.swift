import Layout
import SwiftUI
import UIKit
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §3.1, D2, D9; role P): the one-page heading and all-day band of 1.2.3 (43fe366),
// kept here as they were so that PaperSpanTests can hold today's one-page path against them, pixel for
// pixel: with span off and for a window of one page the app must draw what 1.2.3 drew. Copied from 43fe366's
// Views/StickyHeaderView.swift (`weekRow`, `dayRow` and what they use) and Views/AllDayBandView.swift (the
// whole view); only the type names, `private` on the copies and the comments differ. They are the reference:
// never change them to follow the app.

/// 43fe366's `StickyHeaderView` for a week or a day page (`weekRow`, `dayRow`); nothing for a month or a year.
struct Frozen123StickyHeader: View {
    var paper: PaperContent
    var viewport: PaperViewport
    var language: UILanguage = L.language
    var onDayTap: (DayKey) -> Void = { _ in }

    var body: some View {
        switch paper {
        case .week(let content):
            weekRow(content.layout)
        case .day(let content):
            dayRow(content.layout)
        case .month, .year:
            EmptyView()
        }
    }

    private func weekRow(_ layout: WeekPageLayout) -> some View {
        let columns = [PaperSpec.weekGutter] + Array(repeating: PaperSpec.weekColumnWidth, count: PaperSpec.weekColumns)
        return PaperRow(kind: .week, viewport: viewport, columns: columns) {
            Color.clear
            ForEach(layout.dateLabels, id: \.day) { label in
                weekDayCell(label)
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    private static let narrowWeekColumnPoints: CGFloat = PaperWords.narrowWeekColumnPoints

    private func weekDayCell(_ label: DateLabel) -> some View {
        let firstOfMonth = label.day.day == 1
        let number = firstOfMonth ? "\(label.day.month)/1" : "\(label.day.day)"
        let stacked = PaperWords.weekColumnStacksWeekday(L.language)
        let showsWeekday = stacked || !(firstOfMonth && viewport.width(ofPaper: PaperSpec.weekColumnWidth) < Self.narrowWeekColumnPoints)
        let tone = Self.toneColor(label.tone)
        return Button {
            onDayTap(label.day)
        } label: {
            VStack(spacing: 1) {
                Group {
                    if stacked {
                        VStack(spacing: 0) {
                            weekDayWeekday(label, tone: tone)
                            weekDayNumber(number, label, tone: tone)
                        }
                    } else {
                        HStack(spacing: 4) {
                            if showsWeekday {
                                weekDayWeekday(label, tone: tone)
                            }
                            weekDayNumber(number, label, tone: tone)
                        }
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                if let holiday = label.holidayName, !holiday.isEmpty {
                    if let short = PaperWords.weekColumnShortHoliday(label, L.language) {
                        ViewThatFits(in: .horizontal) {
                            weekDayHoliday(holiday)
                            weekDayHoliday(short)
                        }
                    } else {
                        weekDayHoliday(holiday)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(label.isToday ? todayTint : (label.tone != .normal ? weekendTint : Color.clear))
            .overlay(alignment: .leading) { columnLine }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.format("header.day.spoken", Self.dayLabel(label)))
    }

    private func weekDayWeekday(_ label: DateLabel, tone: Color?) -> some View {
        Text(PaperWords.weekColumnWeekday(label.day.weekday, columnWidth: viewport.width(ofPaper: PaperSpec.weekColumnWidth), L.language))
            .font(.system(size: 12, weight: label.isToday ? .bold : .medium))
            .foregroundStyle(label.isToday ? accentColor : (tone ?? ink2))
    }

    private func weekDayNumber(_ number: String, _ label: DateLabel, tone: Color?) -> some View {
        Text(number)
            .font(.system(size: 18, weight: .semibold).monospacedDigit())
            .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
            .padding(.horizontal, 6)
            .frame(minWidth: 30, minHeight: 30)
            .background(label.isToday ? Capsule().fill(accentColor) : nil)
    }

    private func weekDayHoliday(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 10))
            .foregroundStyle(redColor)
            .lineLimit(1)
    }

    private func dayRow(_ layout: DayPageLayout) -> some View {
        let timeline = PaperSpec.dayTimelineRight - PaperSpec.dayGutter
        let memo = PaperSpec.dayWidth - PaperSpec.dayTimelineRight
        let label = layout.dateLabels.first
        return PaperRow(kind: .day, viewport: viewport, columns: [PaperSpec.dayGutter, timeline, memo]) {
            Color.clear
            if let label = label {
                dayDateBlock(label)
            } else {
                Color.clear
            }
            Color.clear
                .overlay(alignment: .leading) { Rectangle().fill(lineStrongColor).frame(width: 1) }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.map { Self.dayLabel($0) } ?? "")
    }

    private func dayDateBlock(_ label: DateLabel) -> some View {
        dayDateContent(label)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(label.isToday ? todayTintSoft : (label.tone != .normal ? weekendTintSoft : Color.clear))
            .overlay(alignment: .leading) { columnLine }
    }

    @ViewBuilder
    private func dayDateContent(_ label: DateLabel) -> some View {
        if let line = PaperWords.dayHeadingHolidayLine(label, language) {
            ViewThatFits(in: .horizontal) {
                dayDateRow(label)
                dayDateRow(label, holidayLine: line)
                dayDateRow(label, holidayLine: line, wraps: true)
                    .frame(maxHeight: PaperWords.dayHeadingLinesMaxHeight)
            }
        } else {
            dayDateRow(label)
        }
    }

    private func dayDateRow(_ label: DateLabel, holidayLine: String? = nil, wraps: Bool = false) -> some View {
        let tone = Self.toneColor(label.tone)
        let fit = PaperWords.dayHeadingFit(language)
        return HStack(spacing: holidayLine == nil ? 10 : 6) {
            Text("\(label.day.day)")
                .font(.system(size: 21, weight: .semibold).monospacedDigit())
                .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
                .padding(.horizontal, 6)
                .frame(minWidth: 36, minHeight: 36)
                .background(label.isToday ? Capsule().fill(accentColor) : nil)
            VStack(alignment: .leading, spacing: 0) {
                Text(holidayLine ?? DateText.monthName(label.day.month, .full, language))
                    .font(.system(size: wraps ? PaperWords.dayHeadingLongHolidayPoints : 11))
                    .foregroundStyle(holidayLine == nil ? ink3 : redColor)
                    .lineLimit(wraps ? 2 : fit.lineLimit)
                    .minimumScaleFactor(wraps ? 1 : fit.minScale)
                Text(DateText.weekdays(.full, language)[label.day.weekday])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(label.isToday ? accentColor : (tone ?? ink1))
                    .lineLimit(fit.lineLimit)
                    .minimumScaleFactor(fit.minScale)
            }
            if holidayLine == nil, let holiday = label.holidayName, !holiday.isEmpty {
                Text(holiday)
                    .font(.system(size: 12))
                    .foregroundStyle(redColor)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(redColor.opacity(0.08)))
                    .layoutPriority(fit.holidayPriority)
            }
        }
    }

    private static func dayLabel(_ label: DateLabel, language: UILanguage = L.language) -> String {
        var text = DateText.spokenDay(label.day, language)
        if let holiday = label.holidayName, !holiday.isEmpty {
            text += (language == .ja ? " " : ", ") + holiday
        }
        return text
    }

    private static func toneColor(_ tone: DayTone) -> Color? {
        switch tone {
        case .saturday: return Color(uiColor: PaperPalette.blue)
        case .sundayOrHoliday: return Color(uiColor: PaperPalette.red)
        case .normal: return nil
        }
    }

    private var paperColor: Color { Color(uiColor: PaperPalette.paper) }
    private var ink1: Color { Color(uiColor: PaperPalette.ink1) }
    private var ink2: Color { Color(uiColor: PaperPalette.ink2) }
    private var ink3: Color { Color(uiColor: PaperPalette.ink3) }
    private var accentColor: Color { Color(uiColor: PaperPalette.accent) }
    private var redColor: Color { Color(uiColor: PaperPalette.red) }
    private var lineColor: Color { Color(uiColor: PaperPalette.line) }
    private var lineStrongColor: Color { Color(uiColor: PaperPalette.lineStrong) }
    private var todayTint: Color { Color(uiColor: PaperPalette.todayTint) }
    private var todayTintSoft: Color { Color(uiColor: PaperPalette.todayTintSoft) }
    private var weekendTint: Color { Color(uiColor: PaperPalette.weekendTint) }
    private var weekendTintSoft: Color { Color(uiColor: PaperPalette.weekendTintSoft) }

    private var columnLine: some View {
        Rectangle().fill(lineColor).frame(width: 1)
    }

    private var bottomLine: some View {
        Rectangle().fill(lineColor).frame(height: 1)
    }
}

/// 43fe366's `AllDayBandView`, whole.
struct Frozen123AllDayBand: View {
    var band: AllDayBandLayout
    var viewport: PaperViewport
    var pageHeight: CGFloat
    var laneZoom: CGFloat? = nil
    var onBarTap: (String) -> Void = { _ in }
    var onColumnTap: (DayKey) -> Void = { _ in }
    var onColumnDoubleTap: (DayKey) -> Void = { _ in }

    private static let barCorner: CGFloat = 4
    private static let textPad: CGFloat = 6

    private var metrics: AllDayBandMetrics.Metrics {
        AllDayBandMetrics.metrics(kind: band.kind, laneCount: band.laneCount, zoom: laneZoom ?? viewport.zoom, pageHeight: pageHeight)
    }

    private var width: CGFloat {
        viewport.width.isFinite ? max(0, viewport.width) : 0
    }

    var body: some View {
        if band.laneCount > 0 {
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

    private func content(_ metrics: AllDayBandMetrics.Metrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(band.days.indices, id: \.self) { index in
                column(index, metrics)
            }
            gutterLabel(metrics)
            ForEach(band.bars) { bar in
                barView(bar, metrics)
            }
        }
        .frame(width: width, height: metrics.contentHeight, alignment: .topLeading)
    }

    private func column(_ index: Int, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let day = band.days[index]
        let x = index < band.columnMinX.count ? viewport.x(ofPaper: band.columnMinX[index]) : 0
        let columnWidth = max(0, viewport.width(ofPaper: band.columnWidth))
        let shape = Rectangle()
            .fill(columnTint(index) ?? Color.clear)
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
                    .accessibilityAction { onColumnTap(day) }
            }
        }
        .accessibilityLabel(AllDayBandView.columnLabel(day))
        .accessibilityAddTraits(.isButton)
        .offset(x: x)
    }

    @ViewBuilder
    private func gutterLabel(_ metrics: AllDayBandMetrics.Metrics) -> some View {
        let gutterWidth = max(0, viewport.width(ofPaper: band.gutter))
        if let label = PaperWords.allDayLabel(widthPoints: gutterWidth, fontSize: AllDayBandMetrics.labelPoints, L.language) {
            Text(label)
                .font(.system(size: AllDayBandMetrics.labelPoints))
                .foregroundStyle(ink3)
                .lineLimit(1)
                .padding(.trailing, Self.textPad)
                .frame(width: gutterWidth, height: metrics.lane, alignment: .trailing)
                .clipped()
                .accessibilityHidden(true)
                .offset(x: viewport.x(ofPaper: 0), y: metrics.laneTop(0))
        }
    }

    private func barView(_ bar: AllDayBandBar, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let x = viewport.x(ofPaper: bar.minX)
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
        .accessibilityLabel(AllDayBandView.barLabel(bar))
        .offset(x: x, y: metrics.laneTop(bar.lane))
    }

    private func columnTint(_ index: Int) -> Color? {
        let soft = band.kind == .day
        if band.todayColumn == index {
            return Color(uiColor: soft ? PaperPalette.todayTintSoft : PaperPalette.todayTint)
        }
        guard index < band.tones.count, band.tones[index] != .normal else { return nil }
        return Color(uiColor: soft ? PaperPalette.weekendTintSoft : PaperPalette.weekendTint)
    }

    private static func barShape(_ bar: AllDayBandBar) -> UnevenRoundedRectangle {
        let left: CGFloat = bar.continuesLeft ? 0 : barCorner
        let right: CGFloat = bar.continuesRight ? 0 : barCorner
        return UnevenRoundedRectangle(
            topLeadingRadius: left,
            bottomLeadingRadius: left,
            bottomTrailingRadius: right,
            topTrailingRadius: right
        )
    }

    private var paperColor: Color { Color(uiColor: PaperPalette.paper) }
    private var ink3: Color { Color(uiColor: PaperPalette.ink3) }
    private var lineStrongColor: Color { Color(uiColor: PaperPalette.lineStrong) }
}
