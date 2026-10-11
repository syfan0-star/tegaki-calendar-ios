import Combine
import EventKit
import PencilKit
import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            MonthScreen()
        }
    }
}

/// M1 screen: the month grid (with holiday names) under a PencilKit canvas, and the month's events.
///
/// Ink is kept in plain page coordinates of the canvas for M1 only. Later milestones anchor strokes
/// to day cells so rows can grow with their all-day events (DESIGN.md §3).
struct MonthScreen: View {
    @StateObject private var eventKit = EventKitService()
    @State private var yearMonth = YearMonth.current()
    @State private var drawing = PKDrawing()
    @State private var tool: InkTool = .pen
    /// Pencil only on iPad by default; iPhones have no Pencil so fingers may draw there
    /// (the default is applied once in `onAppear`, where main-actor UIKit calls are safe).
    @State private var fingerDrawingEnabled = false
    @State private var appliedDefaults = false

    private var grid: MonthGrid { MonthLayout.grid(for: yearMonth) }
    private var holidayNames: [DayKey: String] { JapaneseHolidays.names(for: grid.days) }

    var body: some View {
        VStack(spacing: 8) {
            monthNavigation
            inkToolbar

            ZStack {
                MonthGridView(grid: grid, holidayNames: holidayNames, today: DayKey.today())
                CanvasView(
                    drawing: $drawing,
                    tool: $tool,
                    fingerDrawingEnabled: fingerDrawingEnabled
                )
            }
            .layoutPriority(1)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(yearMonth.title)の予定")
                    .font(.headline)
                    .padding(.horizontal, 4)
                EventListView(service: eventKit, monthTitle: yearMonth.title) {
                    reloadEvents()
                }
            }
            .frame(height: 220)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .navigationTitle("手書きカレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !appliedDefaults {
                appliedDefaults = true
                fingerDrawingEnabled = UIDevice.current.userInterfaceIdiom != .pad
            }
        }
        .task { reloadEvents() }
        .onChange(of: yearMonth) { reloadEvents() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            reloadEvents()
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button {
                yearMonth = yearMonth.previous
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("前の月")

            Spacer()
            Text(yearMonth.title)
                .font(.title2.weight(.semibold))
            Spacer()

            Button("今月") {
                yearMonth = YearMonth.current()
            }
            .buttonStyle(.bordered)

            Button {
                yearMonth = yearMonth.next
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("次の月")
        }
    }

    private var inkToolbar: some View {
        HStack(spacing: 12) {
            Picker("ツール", selection: $tool) {
                ForEach(InkTool.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer(minLength: 0)

            Toggle("指でも書く", isOn: $fingerDrawingEnabled)
                .toggleStyle(.button)

            Button("消す") {
                drawing = PKDrawing()
            }
            .buttonStyle(.bordered)
            .disabled(drawing.strokes.isEmpty)
        }
        .font(.callout)
    }

    private func reloadEvents() {
        let start = yearMonth.firstDay.startOfDay()
        let end = yearMonth.next.firstDay.startOfDay()
        eventKit.loadEvents(from: start, to: end)
    }
}
