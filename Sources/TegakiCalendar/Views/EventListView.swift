import EventKit
import SwiftUI
import UIKit

/// The "this month's events" area under the grid: permission prompts, or the list.
struct EventListView: View {
    @ObservedObject var service: EventKitService
    let monthTitle: String
    /// Called after the person granted (or refused) access, so the screen can reload.
    let onAccessChanged: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch service.accessState {
        case .fullAccess:
            if service.events.isEmpty {
                placeholder("\(monthTitle)の予定はありません。")
            } else {
                List(service.events) { event in
                    EventRow(event: event)
                }
                .listStyle(.plain)
            }

        case .notDetermined:
            VStack(spacing: 12) {
                Text("iPad の「カレンダー」に入っている予定（Google カレンダーを含む）を表示します。")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button("予定を読み込む") {
                    Task {
                        await service.requestAccess()
                        onAccessChanged()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .denied, .writeOnly, .restricted:
            VStack(spacing: 12) {
                Text(deniedMessage)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                if service.accessState != .restricted, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("設定を開く") { openURL(url) }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var deniedMessage: String {
        switch service.accessState {
        case .restricted:
            return "この iPad ではカレンダーへのアクセスが制限されています（スクリーンタイムなどの設定）。"
        case .writeOnly:
            return "いまは「追加のみ」の許可になっているため、予定を表示できません。設定アプリ →「手書きカレンダー」→「カレンダー」で「フルアクセス」を選んでください。"
        default:
            return "カレンダーへのアクセスが許可されていません。設定アプリ →「手書きカレンダー」→「カレンダー」で「フルアクセス」を選んでください。"
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

struct EventRow: View {
    let event: CalendarEvent

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.dateFormat = "M/d(E)"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.dateFormat = "H:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(swatchColor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)
                Text(whenLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !event.calendarTitle.isEmpty {
                    Text(event.calendarTitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var swatchColor: Color {
        if let cgColor = event.color { return Color(cgColor: cgColor) }
        return Color.accentColor
    }

    private var whenLabel: String {
        let startDay = Self.dayFormatter.string(from: event.start)
        if event.isAllDay {
            // EventKit's all-day end is the end of the last day, so it still formats as that day.
            let endDay = Self.dayFormatter.string(from: event.end)
            return startDay == endDay ? "\(startDay) 終日" : "\(startDay)〜\(endDay) 終日"
        }
        let endDay = Self.dayFormatter.string(from: event.end)
        let startTime = Self.timeFormatter.string(from: event.start)
        let endTime = Self.timeFormatter.string(from: event.end)
        return startDay == endDay
            ? "\(startDay) \(startTime)〜\(endTime)"
            : "\(startDay) \(startTime)〜\(endDay) \(endTime)"
    }
}
