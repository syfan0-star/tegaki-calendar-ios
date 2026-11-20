import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §4.5, §6; 0d-14): the pictures of 「予定にする」 are drawn at the window's scale. The frozen
// `InkSnapshot.render` keeps its default argument (the main screen's scale), so every call of it outside the frozen files
// passes `scale:` (the screen's `displayScale`, which follows the iPhone Duo's screen); read from the source in code only
// (comments and strings blanked, `WeekMemoSpanTests.codeOnly`). And the scale it is given is the picture's. The first test
// fails on 1.3's tree (CalendarRootScreen.swift:1935 and :2989 of 7895d40 pass no scale).

@MainActor
final class SnapshotScaleTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Every `InkSnapshot.render(` call of Sources/TegakiCalendar outside the 20 frozen files (tools/compat10/DATA_1_1.sha256)
    /// passes `scale:` — the two of the screen (the one page's and the window's 「予定にする」), and any added later.
    func testEverySnapshotPassesTheWindowScale() throws {
        let frozen = try String(contentsOf: Self.repository.appendingPathComponent("tools/compat10/DATA_1_1.sha256"), encoding: .utf8)
            .split(separator: "\n").compactMap { $0.split(separator: " ", omittingEmptySubsequences: true).last.map(String.init) }
        XCTAssertEqual(frozen.count, 20, "the frozen table was read")
        let root = Self.repository.appendingPathComponent("Sources/TegakiCalendar", isDirectory: true)
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL])
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 50, "the app's sources were found (\(root.path))")
        var calls: [(file: String, call: String)] = []
        for url in files {
            let relative = "Sources/TegakiCalendar/" + url.path.components(separatedBy: "/Sources/TegakiCalendar/").last!
            guard !frozen.contains(relative) else { continue }
            let code = WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8))
            calls += ScreenPathsSpanTests.calls(named: "InkSnapshot.render(", in: code).map { (url.lastPathComponent, $0) }
        }
        XCTAssertEqual(calls.map(\.file), ["CalendarRootScreen.swift", "CalendarRootScreen.swift"], "\(calls)")
        for site in calls {
            XCTAssertTrue(site.call.contains("scale: displayScale"), "\(site.file): \(site.call)")
        }
    }

    /// `render(…, scale:)` draws at the scale it is given: the same picture in points at 2 and at 3, its pixels 2× and 3×.
    func testSnapshotHonorsTheScale() throws {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:],
                                                               now: Date(timeIntervalSince1970: 1_790_000_000)))
        let points = (0..<12).map { i in
            InkPoint(x: 10 + CGFloat(i) * 25, y: 20 + CGFloat(i) * 3, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5,
                     azimuth: 0, altitude: .pi / 2)
        }
        let stroke = InkStroke(id: InkStroke.newId(), cell: .day(DayKey(year: 2026, month: 10, day: 7)), tool: .pen, color: "#1f2937",
                               t: 1_790_000_000_000, points: points)
        let two = try XCTUnwrap(InkSnapshot.render(strokes: [stroke], cells: layout.cells, scale: 2))
        let three = try XCTUnwrap(InkSnapshot.render(strokes: [stroke], cells: layout.cells, scale: 3))
        XCTAssertEqual(two.scale, 2)
        XCTAssertEqual(three.scale, 3)
        XCTAssertEqual(two.size.width, three.size.width, accuracy: 0.01, "the same picture in points")
        XCTAssertEqual(two.size.height, three.size.height, accuracy: 0.01)
        let twoPixels = try XCTUnwrap(two.cgImage)
        let threePixels = try XCTUnwrap(three.cgImage)
        XCTAssertNotEqual(twoPixels.width, threePixels.width, "the pixels follow the scale")
        XCTAssertEqual(CGFloat(twoPixels.width), (two.size.width * 2).rounded(), accuracy: 1)
        XCTAssertEqual(CGFloat(threePixels.width), (three.size.width * 3).rounded(), accuracy: 1)
    }
}
