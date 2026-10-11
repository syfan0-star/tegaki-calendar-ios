import Layout
import SwiftUI

/// Read-only details of one event (M2 contract §5; editing comes in M3b): title, when, calendar,
/// location and notes. Opened from a bar, a chip or a box on any page.
struct EventDetailSheet: View {
    let detail: EventDetail
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(uiColor: PaperPalette.color(hex: detail.colorHex)))
                            .frame(width: 6)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(detail.title)
                                .font(.title3.weight(.semibold))
                            Text(EventDateText.when(start: detail.start, end: detail.end, allDay: detail.allDay))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !detail.calendarTitle.isEmpty {
                    Section("カレンダー") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(uiColor: PaperPalette.color(hex: detail.colorHex)))
                                .frame(width: 10, height: 10)
                            Text(detail.calendarTitle)
                        }
                    }
                }

                if let location = detail.location {
                    Section("場所") {
                        Text(location)
                    }
                }

                if let url = detail.url {
                    Section("URL") {
                        Link(url.absoluteString, destination: url)
                            .lineLimit(2)
                    }
                }

                if let notes = detail.notes {
                    Section("メモ") {
                        Text(notes)
                            .font(.body)
                    }
                }

                Section {
                    Text("予定の編集は次の段階で対応します。いまは iPad の「カレンダー」アプリで編集してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
    }
}

/// Japanese date/time strings for the sheets and accessibility labels
/// ("2026年10月4日(日) 9:00〜10:00", "終日").
enum EventDateText {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy年M月d日(E)"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "M月d日(E)"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "H:mm"
        return f
    }()

    /// "2026年10月4日(日)"
    static func dayTitle(_ day: DayKey) -> String {
        dayFormatter.string(from: day.startOfDay())
    }

    /// Full description: all-day ("2026年10月4日(日) 終日", "…〜10月6日(火) 終日") or timed.
    static func when(start: Date, end: Date, allDay: Bool) -> String {
        if allDay {
            let startDay = DayKey(start)
            // `end` is the exclusive next midnight: the last day is the day before it.
            let lastDay = DayKey(end.addingTimeInterval(-1))
            if lastDay <= startDay {
                return "\(dayFormatter.string(from: start)) 終日"
            }
            return "\(dayFormatter.string(from: start))〜\(shortDayFormatter.string(from: lastDay.startOfDay())) 終日"
        }
        let startDay = DayKey(start)
        let endDay = DayKey(end)
        let startText = "\(dayFormatter.string(from: start)) \(timeFormatter.string(from: start))"
        if startDay == endDay {
            return "\(startText)〜\(timeFormatter.string(from: end))"
        }
        return "\(startText)〜\(shortDayFormatter.string(from: end)) \(timeFormatter.string(from: end))"
    }
}
