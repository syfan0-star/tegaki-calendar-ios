import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4 D1b (docs/M7D.md, D0b; docs/M7D_CONTRACT.md §2.1, §4.2): the `duo measure:` line's file. On the iOS 27.x simulators
// `log show` gives the app's NSLog lines only as `<compose failure …>`, so with `--screenshot-measure` each line the app
// logs is also appended to Library/Caches/duo-measure.txt in its data container (`ScreenshotMeasure.measureFile`), which
// duo.yml deletes before a launch and reads after the photo. Here: `ScreenshotMeasure.append` (the exact text and "\n",
// in order, at the end, the file made when missing, a failure ignored); a `ScreenshotMeasure` with a file of its own
// appending exactly the lines it logs, in order and once each, on the unit tests' app window; and without the argument
// (the unit tests have none) `ScreenshotMode.measure` writing nothing, not even the file. Mutations: the append left out
// of `ScreenshotMeasure.write`, or opened without O_APPEND (a truncating write), fails `testMeasureAppendsTheLinesItLogs`
// and `testAppendAddsEachLineAtTheEnd`; the gate `isMeasuring` dropped from `ScreenshotMode.measure` fails
// `testNothingIsWrittenWithoutTheArgument`.

@MainActor
final class MeasureLineFileTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        try await super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("MeasureLineFileTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
        try await super.tearDown()
    }

    private func text(_ file: URL) throws -> String {
        try String(contentsOf: file, encoding: .utf8)
    }

    private func screen(_ paper: CGSize) -> ScreenshotMode.MeasureScreen {
        ScreenshotMode.MeasureScreen(kind: .week, paperArea: paper, weekStart: .monday, isPad: false, origin: .app,
                                     finger: false, plan: nil)
    }

    /// Two of D1's lines (`ScreenshotMode.measureLine`, the outer screen's numbers), as the app logs them.
    private func lines() -> (String, String) {
        let plan = ScreenshotMode.MeasurePlan(kind: .week, deviceClass: .iPhone, orientation: .portrait, overviewCap: true)
        func line(_ paper: CGSize, _ hinge: ScreenshotMode.HingeReading) -> String {
            ScreenshotMode.measureLine(window: CGSize(width: 466, height: 678), safe: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
                                       scale: 3, screenSize: CGSize(width: 466, height: 678), paper: paper, plan: plan,
                                       hinge: hinge, origin: .app, finger: false)
        }
        return (line(CGSize(width: 466, height: 520), .none), line(CGSize(width: 466, height: 520), .closed))
    }

    /// The exact text and "\n", each line at the end of what is there, in order; the file is made when missing and never
    /// emptied; a file that cannot be opened (its folder missing) is skipped without a throw.
    func testAppendAddsEachLineAtTheEnd() throws {
        let file = folder.appendingPathComponent(ScreenshotMeasure.measureFileName)
        let (first, second) = lines()
        XCTAssertTrue(first.hasPrefix("duo measure: window=466.00x678.00 "), first)
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        ScreenshotMeasure.append(first, to: file)
        XCTAssertEqual(try text(file), first + "\n", "made when missing, the line as logged")
        ScreenshotMeasure.append(second, to: file)
        XCTAssertEqual(try text(file), first + "\n" + second + "\n", "appended, in order")
        ScreenshotMeasure.append(first, to: file)
        XCTAssertEqual(try text(file), first + "\n" + second + "\n" + first + "\n", "the same text again is appended again")

        let lost = folder.appendingPathComponent("missing").appendingPathComponent(ScreenshotMeasure.measureFileName)
        ScreenshotMeasure.append(first, to: lost)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lost.path), "nothing written, nothing thrown")
    }

    /// With `--screenshot-measure` (a `ScreenshotMeasure` made here, as `shared` is made then): every line it logs is
    /// appended to its file, in order, once (a call with the same values logs nothing and appends nothing), with nothing
    /// else in the file. The hinge is answered first, as the unit tests' simulator answers it (no hinge), so a late update
    /// of the interaction on the app's window changes no line; the wait for it returns at once and adds nothing.
    func testMeasureAppendsTheLinesItLogs() async throws {
        let file = folder.appendingPathComponent(ScreenshotMeasure.measureFileName)
        let measurer = ScreenshotMeasure(sleep: { _ in }, lineFile: file)
        XCTAssertEqual(measurer.lineFile, file)
        measurer.hingeAnswered(.none)
        XCTAssertNil(measurer.lastLine, "no screen yet: no line")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        measurer.note(screen(CGSize(width: 300, height: 400)))
        let first = try XCTUnwrap(measurer.lastLine, "the unit tests run inside the app: its window is measured")
        measurer.note(screen(CGSize(width: 300, height: 400)))
        measurer.note(screen(CGSize(width: 300, height: 500)))
        let second = try XCTUnwrap(measurer.lastLine)
        for _ in 0..<10 { await Task.yield() }

        XCTAssertTrue(first.hasPrefix("duo measure: window="), first)
        XCTAssertTrue(first.contains(" paper=300.00x400.00 "), first)
        XCTAssertTrue(second.contains(" paper=300.00x500.00 "), second)
        XCTAssertTrue(second.hasSuffix(" origin=app finger=false"), second)
        XCTAssertEqual(try text(file), first + "\n" + second + "\n")
    }

    /// Without `--screenshot-measure` (normal use, the J-4 photos, the unit tests): `ScreenshotMode.measure` returns before
    /// `ScreenshotMeasure`, so Library/Caches/duo-measure.txt is never made.
    func testNothingIsWrittenWithoutTheArgument() throws {
        XCTAssertFalse(ScreenshotMode.isMeasuring, "the unit tests run without --screenshot-measure")
        XCTAssertEqual(ScreenshotMode.parse(["app", "--screenshot-mode"])?.measure, false)
        XCTAssertEqual(ScreenshotMode.parse(["app", "--screenshot-mode", "--screenshot-measure"])?.measure, true)
        let file = try XCTUnwrap(ScreenshotMeasure.measureFile)
        XCTAssertEqual(file.lastPathComponent, "duo-measure.txt")
        XCTAssertEqual(file.deletingLastPathComponent().lastPathComponent, "Caches")
        XCTAssertEqual(file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Library")
        try? FileManager.default.removeItem(at: file)

        ScreenshotMode.measure(kind: .week, paperArea: CGSize(width: 300, height: 400), weekStart: .monday, isPad: false,
                               origin: .app, finger: false)
        ScreenshotMode.measure(kind: .day, paperArea: CGSize(width: 300, height: 500), weekStart: .sunday, isPad: false,
                               origin: .person, finger: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}
