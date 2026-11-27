import CoreGraphics
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.5–§3.9, §6.1, 0f-9–0f-16): the colour panel's pure rules (`ColorPanelLogic`): what a press
/// of a pen dot does, a choice and 「最初の色に戻す」, where the panel goes on every edge of the bar, which touch and which move of
/// the lit dot close it, when the system picker's colour is taken (with the picker's coordinator), and the dots' rims. Fails
/// with the picker's moving colour taken (mutation MC3), the panel always above its dot (MC4), a touch inside it closing it
/// (MC6b), 「最初の色に戻す」 leaving the pen (MC7), or a moved dot not closing it (MC8).
@MainActor
final class ColorPanelLogicTests: XCTestCase {
    private typealias Logic = ColorPanelLogic
    private let first = ToolbarPalette.defaultSlots
    private let brown = "#92400e"

    // MARK: Presses (§3.5)

    func testATap() {
        // The lit dot opens its panel, and closes it when it is open.
        XCTAssertEqual(Logic.tap(slot: 0, lit: 0, openSlot: nil), .open(0))
        XCTAssertEqual(Logic.tap(slot: 3, lit: 3, openSlot: nil), .open(3))
        XCTAssertEqual(Logic.tap(slot: 0, lit: 0, openSlot: 0), .close)
        // Any other dot is chosen, open or not (the panel closes with it).
        XCTAssertEqual(Logic.tap(slot: 1, lit: 0, openSlot: nil), .select(1))
        XCTAssertEqual(Logic.tap(slot: 1, lit: 0, openSlot: 0), .select(1))
        XCTAssertEqual(Logic.tap(slot: 5, lit: nil, openSlot: nil), .select(5), "no dot lit: chosen")
    }

    func testALongPress() {
        XCTAssertEqual(Logic.longPress(slot: 0, lit: 0, openSlot: nil), .open(0), "the lit dot opens")
        XCTAssertEqual(Logic.longPress(slot: 2, lit: 2, openSlot: 2), .none, "an open panel stays (its lift does not close it)")
        XCTAssertEqual(Logic.longPress(slot: 1, lit: 0, openSlot: nil), .select(1), "another dot: as a tap")
        XCTAssertEqual(Logic.longPress(slot: 1, lit: 0, openSlot: 0), .select(1))
        XCTAssertEqual(Logic.longPress(slot: 4, lit: nil, openSlot: nil), .select(4))
    }

    // MARK: A choice and the reset (§3.7)

    func testAChoice() {
        // A colour no dot has: dot 0 takes it, the pen too.
        XCTAssertEqual(Logic.choose(brown, slot: 0, slots: first), Logic.Choice(slots: [brown] + first.dropFirst(), pen: brown))
        XCTAssertEqual(Logic.choose(brown, slot: 4, slots: first),
                       Logic.Choice(slots: Array(first.prefix(4)) + [brown, first[5]], pen: brown))
        // A colour another dot has: the dots stay, the pen takes it (that dot lights).
        XCTAssertEqual(Logic.choose(first[1], slot: 0, slots: first), Logic.Choice(slots: first, pen: first[1]))
        let mine = [brown] + first.dropFirst()
        XCTAssertEqual(Logic.choose(first[1], slot: 0, slots: mine), Logic.Choice(slots: mine, pen: first[1]), "茶 stays on dot 0")
        // Its own colour: nothing changes.
        XCTAssertEqual(Logic.choose(brown, slot: 0, slots: mine), Logic.Choice(slots: mine, pen: brown))
        // Normalized first; an unreadable colour changes nothing.
        XCTAssertEqual(Logic.choose("#92400E", slot: 0, slots: first).slots[0], brown)
        XCTAssertEqual(Logic.choose("#0AC", slot: 2, slots: first).slots[2], "#00aacc")
        XCTAssertEqual(Logic.choose("nope", slot: 2, slots: first), Logic.Choice(slots: first, pen: first[2]))
        // Never two alike.
        for hex in ToolbarPalette.panelColors.map(\.hex) + ["#0a7e8c"] {
            for slot in 0..<6 {
                let choice = Logic.choose(hex, slot: slot, slots: mine)
                XCTAssertEqual(Set(choice.slots).count, 6, "\(hex) on \(slot)")
                XCTAssertTrue(choice.slots.contains(choice.pen), "\(hex) on \(slot): the pen is a dot")
            }
        }
    }

    func testTheReset() {
        let mine = [brown, "#6b7280", first[2], "#0a7e8c", first[4], first[5]]
        // The pen on dot k becomes the k-th first colour (the same dot lights).
        XCTAssertEqual(Logic.reset(currentPen: brown, slots: mine), Logic.Choice(slots: first, pen: first[0]))
        XCTAssertEqual(Logic.reset(currentPen: "#6b7280", slots: mine), Logic.Choice(slots: first, pen: first[1]))
        XCTAssertEqual(Logic.reset(currentPen: "#0A7E8C", slots: mine), Logic.Choice(slots: first, pen: first[3]), "either case")
        XCTAssertEqual(Logic.reset(currentPen: first[2], slots: mine), Logic.Choice(slots: first, pen: first[2]))
        // A pen on no dot: the first dot's.
        XCTAssertEqual(Logic.reset(currentPen: "#123456", slots: mine), Logic.Choice(slots: first, pen: first[0]))
        // Already the first six: the same.
        XCTAssertEqual(Logic.reset(currentPen: first[5], slots: first), Logic.Choice(slots: first, pen: first[5]))
    }

    // MARK: Where the panel goes (§3.8)

    private let panel = ColorPanelLogic.panelSize

    /// The panel inside the container by 8, off the dot, and on the side of the bar's edge away from it (8 from the dot).
    private func check(_ frame: CGRect, anchor: CGRect, edge: PaletteEdge, container: CGRect, _ name: String,
                       file: StaticString = #filePath, line: UInt = #line) {
        let inner = container.insetBy(dx: 8, dy: 8)
        XCTAssertEqual(frame.size, panel, name, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, inner.minX - 0.001, "\(name): left", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, inner.maxX + 0.001, "\(name): right", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, inner.minY - 0.001, "\(name): top", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, inner.maxY + 0.001, "\(name): bottom", file: file, line: line)
        XCTAssertFalse(frame.intersects(anchor), "\(name): off the dot", file: file, line: line)
        switch edge {
        case .bottom:
            XCTAssertEqual(frame.maxY, anchor.minY - 8, accuracy: 0.001, "\(name): 8 above the dot", file: file, line: line)
        case .top:
            XCTAssertEqual(frame.minY, anchor.maxY + 8, accuracy: 0.001, "\(name): 8 under the dot", file: file, line: line)
        case .left:
            XCTAssertEqual(frame.minX, anchor.maxX + 8, accuracy: 0.001, "\(name): 8 right of the dot", file: file, line: line)
        case .right:
            XCTAssertEqual(frame.maxX, anchor.minX - 8, accuracy: 0.001, "\(name): 8 left of the dot", file: file, line: line)
        }
    }

    func testThePlacements() {
        // The iPhone 17's bottom bar (402 × 874, safe area 62 / 34: the layer 402 × 778); its dots near the left and near
        // the right end of the scrolled row: the panel slides along the bar into the screen.
        let phone = CGRect(x: 0, y: 0, width: 402, height: 778)
        let phoneLeft = CGRect(x: 14, y: 718, width: 38, height: 44)
        let left = Logic.placement(anchor: phoneLeft, edge: .bottom, container: phone, panel: panel)
        check(left, anchor: phoneLeft, edge: .bottom, container: phone, "iPhone, the leftmost dot")
        XCTAssertEqual(left.minX, 8, "pushed to the left margin")
        let phoneRight = CGRect(x: 352, y: 718, width: 38, height: 44)
        let right = Logic.placement(anchor: phoneRight, edge: .bottom, container: phone, panel: panel)
        check(right, anchor: phoneRight, edge: .bottom, container: phone, "iPhone, the rightmost dot")
        XCTAssertEqual(right.maxX, 394, "pushed to the right margin")

        // The 13-inch iPad (1032 × 1376, safe area 24 / 20: the layer 1032 × 1332).
        let pad = CGRect(x: 0, y: 0, width: 1032, height: 1332)
        let bottom = CGRect(x: 273, y: 1262, width: 38, height: 44)
        let below = Logic.placement(anchor: bottom, edge: .bottom, container: pad, panel: panel)
        check(below, anchor: bottom, edge: .bottom, container: pad, "13-inch, bottom")
        XCTAssertEqual(below.midX, bottom.midX, accuracy: 0.001, "centred on the dot")
        let top = CGRect(x: 273, y: 160, width: 38, height: 44)
        let under = Logic.placement(anchor: top, edge: .top, container: pad, panel: panel)
        check(under, anchor: top, edge: .top, container: pad, "13-inch, top")
        XCTAssertEqual(under.midX, top.midX, accuracy: 0.001)
        let side = CGRect(x: 14, y: 420, width: 44, height: 38)
        let rightOfLeftBar = Logic.placement(anchor: side, edge: .left, container: pad, panel: panel)
        check(rightOfLeftBar, anchor: side, edge: .left, container: pad, "13-inch, left")
        XCTAssertEqual(rightOfLeftBar.midY, side.midY, accuracy: 0.001, "centred on the dot")
        let sideRight = CGRect(x: 974, y: 420, width: 44, height: 38)
        let leftOfRightBar = Logic.placement(anchor: sideRight, edge: .right, container: pad, panel: panel)
        check(leftOfRightBar, anchor: sideRight, edge: .right, container: pad, "13-inch, right")
        XCTAssertEqual(leftOfRightBar.midY, sideRight.midY, accuracy: 0.001)
        // A dot near the top of the upright bar: the panel slides down into the screen.
        let high = CGRect(x: 14, y: 30, width: 44, height: 38)
        let slid = Logic.placement(anchor: high, edge: .left, container: pad, panel: panel)
        check(slid, anchor: high, edge: .left, container: pad, "13-inch, left, high")
        XCTAssertEqual(slid.minY, 8)

        // The iPad mini's upright bar on the left (744 × 1133, safe area 24 / 20).
        let mini = CGRect(x: 0, y: 0, width: 744, height: 1089)
        let miniDot = CGRect(x: 14, y: 400, width: 44, height: 38)
        check(Logic.placement(anchor: miniDot, edge: .left, container: mini, panel: panel), anchor: miniDot, edge: .left,
              container: mini, "mini, left")

        // The 13-inch's bottom peek (laid over the paper, 6 above the bottom): the same rule.
        let peek = CGRect(x: 273, y: 1270, width: 38, height: 44)
        check(Logic.placement(anchor: peek, edge: .bottom, container: pad, panel: panel), anchor: peek, edge: .bottom,
              container: pad, "13-inch, bottom peek")
    }

    func testThePanelFitsEveryPhone() {
        XCTAssertEqual(panel.width, 288)
        XCTAssertLessThanOrEqual(panel.width + 2 * 8, 375 - 2 * 12, "a 375 pt iPhone with the screen's 12 and 8 on each side")
        XCTAssertEqual(panel.height, 204)
        XCTAssertGreaterThanOrEqual(panel.height, 12 + 2 * ColorPanelLogic.cellSide + 8 + 2 * ColorPanelLogic.rowHeight)
        XCTAssertEqual(CGFloat(ColorPanelLogic.columns) * ColorPanelLogic.cellSide, 264)
        XCTAssertEqual(ToolbarPalette.panelColors.count % ColorPanelLogic.columns, 0, "two full rows")
    }

    // MARK: Closing (§3.6)

    func testATouchClosesOutsideOnly() {
        let panelFrame = CGRect(x: 100, y: 500, width: 288, height: 204)
        let dot = CGRect(x: 273, y: 718, width: 38, height: 44)
        XCTAssertFalse(Logic.closesOnTouch(at: CGPoint(x: 200, y: 600), panel: panelFrame, litSwatch: dot), "inside the panel")
        XCTAssertFalse(Logic.closesOnTouch(at: CGPoint(x: 101, y: 501), panel: panelFrame, litSwatch: dot), "inside, at its corner")
        XCTAssertFalse(Logic.closesOnTouch(at: CGPoint(x: 290, y: 740), panel: panelFrame, litSwatch: dot), "on the lit dot")
        XCTAssertTrue(Logic.closesOnTouch(at: CGPoint(x: 50, y: 300), panel: panelFrame, litSwatch: dot), "on the paper")
        XCTAssertTrue(Logic.closesOnTouch(at: CGPoint(x: 320, y: 740), panel: panelFrame, litSwatch: dot), "on the next dot")
        XCTAssertTrue(Logic.closesOnTouch(at: CGPoint(x: 200, y: 710), panel: panelFrame, litSwatch: dot), "just under the panel")
        XCTAssertTrue(Logic.closesOnTouch(at: CGPoint(x: 290, y: 740), panel: panelFrame, litSwatch: nil), "no dot: outside")
    }

    func testAMovedDotCloses() {
        let opened = CGRect(x: 273, y: 718, width: 38, height: 44)
        XCTAssertFalse(Logic.closesOnAnchorMove(opened: opened, now: opened), "the same")
        XCTAssertFalse(Logic.closesOnAnchorMove(opened: opened, now: opened.offsetBy(dx: 0.5, dy: -0.5)), "within 1 pt")
        XCTAssertFalse(Logic.closesOnAnchorMove(opened: opened, now: opened.offsetBy(dx: 1, dy: 1)), "1 pt")
        XCTAssertTrue(Logic.closesOnAnchorMove(opened: opened, now: opened.offsetBy(dx: -2, dy: 0)), "2 pt across (the row scrolled)")
        XCTAssertTrue(Logic.closesOnAnchorMove(opened: opened, now: opened.offsetBy(dx: 0, dy: 2)), "2 pt up or down")
        XCTAssertTrue(Logic.closesOnAnchorMove(opened: opened, now: CGRect(x: 273, y: 718, width: 44, height: 38)),
                      "another size (the bar turned upright)")
        XCTAssertTrue(Logic.closesOnAnchorMove(opened: opened, now: opened.offsetBy(dx: -150, dy: 0)), "scrolled away")
    }

    // MARK: The system picker (§3.7)

    func testThePickersColourIsTakenWhenItStops() {
        XCTAssertTrue(Logic.commitsPick(continuously: false))
        XCTAssertFalse(Logic.commitsPick(continuously: true), "nothing written while a finger drags in the picker")

        var picks: [String] = []
        var dones = 0
        let sheet = ColorPickerSheet(initialHex: brown, onPick: { picks.append($0) }, onDone: { dones += 1 })
        let coordinator = sheet.makeCoordinator()
        coordinator.picked("#0a7e8c", continuously: true)
        coordinator.picked("#0b7f8d", continuously: true)
        XCTAssertEqual(picks, [], "still moving")
        XCTAssertEqual(coordinator.pending, "#0b7f8d")
        coordinator.picked("#0c808e", continuously: false)
        XCTAssertEqual(picks, ["#0c808e"], "it stopped: taken")
        XCTAssertNil(coordinator.pending)
        coordinator.picked(nil, continuously: false)
        XCTAssertEqual(picks, ["#0c808e"], "a colour without an RGB form is not taken")
        // Closed while a candidate still moved: taken, then onDone; once.
        coordinator.picked("#123456", continuously: true)
        coordinator.finish()
        XCTAssertEqual(picks, ["#0c808e", "#123456"])
        XCTAssertEqual(dones, 1)
        coordinator.finish()
        coordinator.picked("#654321", continuously: false)
        XCTAssertEqual(picks, ["#0c808e", "#123456"], "nothing after it closed")
        XCTAssertEqual(dones, 1, "onDone once (the ×, then the sheet going away)")

        // Closed with nothing chosen: onDone only.
        var none: [String] = []
        var closed = 0
        let other = ColorPickerSheet(initialHex: brown, onPick: { none.append($0) }, onDone: { closed += 1 }).makeCoordinator()
        other.colorPickerViewControllerDidFinish(UIColorPickerViewController())
        XCTAssertEqual(none, [])
        XCTAssertEqual(closed, 1)
    }

    // MARK: The rims (§3.9)

    func testTheRims() {
        XCTAssertEqual(Logic.swatchRim(dark: false).white, false)
        XCTAssertEqual(Logic.swatchRim(dark: false).opacity, 0.15)
        XCTAssertEqual(Logic.swatchRim(dark: true).white, true)
        XCTAssertEqual(Logic.swatchRim(dark: true).opacity, 0.35)
    }
}
