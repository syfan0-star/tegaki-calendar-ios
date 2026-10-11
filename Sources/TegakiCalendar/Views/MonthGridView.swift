import SwiftUI

/// The month page's grid: Monday-start, 7 columns, Japanese weekday headers, holiday names in red,
/// Saturdays in blue, today highlighted. Only the rows that contain days of the month are shown.
struct MonthGridView: View {
    let grid: MonthGrid
    let holidayNames: [DayKey: String]
    let today: DayKey

    private static let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { column in
                    Text(Self.weekdayLabels[column])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.headerColor(column: column))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .border(Color(uiColor: .separator), width: 0.5)

            ForEach(grid.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { day in
                        DayCell(
                            day: day,
                            isInMonth: grid.contains(day),
                            isToday: day == today,
                            holidayName: holidayNames[day]
                        )
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private static func headerColor(column: Int) -> Color {
        switch column {
        case 5: return .blue   // 土
        case 6: return .red    // 日
        default: return .primary
        }
    }
}

struct DayCell: View {
    let day: DayKey
    let isInMonth: Bool
    let isToday: Bool
    let holidayName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(day.day)")
                .font(.body.weight(isToday ? .bold : .regular))
                .foregroundStyle(numberColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    if isToday {
                        Capsule().fill(Color.accentColor.opacity(0.22))
                    }
                }
            if let holidayName = holidayName {
                Text(holidayName)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isInMonth ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground))
        .border(Color(uiColor: .separator), width: 0.5)
        .opacity(isInMonth ? 1 : 0.5)
    }

    private var numberColor: Color {
        if holidayName != nil || day.weekday == 0 { return .red }
        if day.weekday == 6 { return .blue }
        return .primary
    }
}
