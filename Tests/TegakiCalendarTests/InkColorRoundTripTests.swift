import InkModel
import Layout
import PencilKit
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.7, §5.3, §6.1, 0f-13, 0f-24): the app's side of a stroke in a colour of the panel or of
/// 「その他の色…」. A Display P3 colour from the system picker becomes this app's sRGB "#rrggbb" at once (the frozen
/// `InkColors.hex(of:)`: resolved light, clamped to 0…1), and from that text the pen's PencilKit ink and the stroke it writes
/// give the same text back — so the colour written and the colour read after a relaunch are one. A brown stroke goes through
/// the ledger (the frozen `InkLedgerTests.testNewStrokeGetsIdAndCell`'s way) with its colour, and back into a drawing in it.
/// Fails if the picker's colour were kept as it came (not made sRGB).
@MainActor
final class InkColorRoundTripTests: XCTestCase {
    private let pageId = "m1-2026-10"

    private func stroke(_ ink: PKInk, at origin: CGPoint) -> PKStroke {
        let points = (0..<5).map { i in
            PKStrokePoint(location: CGPoint(x: origin.x + CGFloat(i) * 3, y: origin.y + CGFloat(i)), timeOffset: TimeInterval(i) * 0.01,
                          size: CGSize(width: 3.5, height: 3.5), opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()), transform: .identity, mask: nil)
    }

    func testAPickedColourIsTheSameTextAllTheWay() throws {
        let picked: [UIColor] = [
            UIColor(displayP3Red: 0.05, green: 0.55, blue: 0.6, alpha: 1),
            UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1),        // outside sRGB: clamped
            UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1),
            UIColor(red: 0x92 / 255, green: 0x40 / 255, blue: 0x0e / 255, alpha: 1),
            UIColor(white: 0.5, alpha: 1),
        ]
        for color in picked {
            let hex = try XCTUnwrap(InkColors.hex(of: color), "\(color)")
            XCTAssertEqual(InkColors.normalized(hex), hex, "lower-case #rrggbb: \(hex)")
            let pen = InkStyle(tool: .pen, colorHex: hex, width: 3.5)
            XCTAssertEqual(pen.colorHex, hex)
            XCTAssertEqual(InkColors.hex(of: pen.pkInkingTool.color), hex, "the canvas's tool writes \(hex)")
            let written = stroke(pen.pkInk, at: CGPoint(x: 10, y: 20))
            XCTAssertEqual(InkColors.hex(of: written.ink.color), hex, "the stroke reads back \(hex)")
            // The choice the screen makes with it.
            let choice = ColorPanelLogic.choose(hex, slot: 3, slots: ToolbarPalette.defaultSlots)
            XCTAssertTrue(choice.pen == hex && choice.slots.contains(hex), hex)
        }
        // A P3 red outside sRGB is clamped, not wrapped.
        XCTAssertEqual(InkColors.hex(of: UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1))?.prefix(3), "#ff")
    }

    func testABrownStrokeThroughTheLedger() throws {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:],
                                                               now: Date(timeIntervalSince1970: 1_790_000_000)))
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout, deviceId: "test-device")
        _ = ledger.drawing()
        let day = DayKey(year: 2026, month: 10, day: 7)
        let cell = try XCTUnwrap(layout.cells[.day(day)])
        let brown = InkStyle(tool: .pen, colorHex: "#92400e", width: 3.5)
        let other = InkStyle(tool: .pen, colorHex: "#0a7e8c", width: 6)
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [
            stroke(brown.pkInk, at: CGPoint(x: cell.minX + 50, y: cell.minY + 60)),
            stroke(other.pkInk, at: CGPoint(x: cell.minX + 80, y: cell.minY + 90)),
        ]))
        XCTAssertEqual(change.added.count, 2)
        XCTAssertEqual(Set(change.added.map(\.color)), ["#92400e", "#0a7e8c"], "the colours as the pen wrote them")
        XCTAssertEqual(Set(ledger.page.liveStrokes.map(\.color)), ["#92400e", "#0a7e8c"])
        // Written and read again (the page's file), then drawn again in the same colours.
        let file = try InkPageCodec.encode(ledger.page)
        let read = try InkPageCodec.decode(file)
        XCTAssertEqual(read, ledger.page)
        let again = InkLedger(page: read, layout: layout, deviceId: "test-device")
        let colours = again.drawing().strokes.compactMap { InkColors.hex(of: $0.ink.color) }
        XCTAssertEqual(Set(colours), ["#92400e", "#0a7e8c"], "drawn again in their colours")
    }
}
