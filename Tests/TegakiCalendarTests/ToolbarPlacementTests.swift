import CoreGraphics
import Foundation
import Layout
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.3–§4.11, §6.1 T; 0e-14 … 0e-22): where the open toolbar may sit and the pure rules
/// around it — the edges a window allows (`allowedEdges`, iPhones and narrow iPad windows the bottom only), the edge shown
/// (`effectiveEdge`, the stored one kept), the snap of a drop (`snapEdge`: the middle keeps the edge, a flick carries it,
/// a disallowed edge is never chosen, ties), the step of a drop (`placementChosen`), the slots (74, 60, the bottom bar's
/// explicit 8), the paddings of 1.4 unchanged, the toast's side inset, the stored value, the grip's and the outlines'
/// geometry and the VoiceOver texts. Mutation MT1 (`allowedEdges` allows the sides at a 678 pt column) fails
/// `testIPadWindows` and `testSideLimits`.
final class ToolbarPlacementTests: XCTestCase {
    private let all: [PaletteEdge] = [.bottom, .top, .left, .right]

    /// The edges of a window of `width` × `height` (pt), its whole width the paper's column and the column under the
    /// header 100 pt shorter than the window (the status bar, the header and the home indicator; the limits themselves
    /// are `testSideLimits`').
    private func edges(isPad: Bool, _ width: CGFloat, _ height: CGFloat) -> [PaletteEdge] {
        ToolbarLogic.allowedEdges(isPad: isPad, windowSize: CGSize(width: width, height: height), column: width,
                                  paperColumnHeight: height - 100)
    }

    // MARK: allowedEdges (§4.3)

    /// Not an iPad: the bottom only, whatever the window — every iPhone upright and on its side, the Duo's outer and inner
    /// screens both ways, and an iPhone Mirroring window as large as a 13-inch iPad. 1.4's bar exactly (no grip).
    func testPhonesKeepTheBottom() {
        let windows: [(CGFloat, CGFloat)] = [(402, 874), (874, 402), (440, 956), (956, 440), (466, 678), (678, 466),
                                             (669, 951), (951, 669), (1032, 1376), (1376, 1032)]
        for (width, height) in windows {
            XCTAssertEqual(edges(isPad: false, width, height), [.bottom], "an iPhone \(width)×\(height)")
            XCTAssertEqual(ToolbarLogic.allowedEdges(isPad: false, windowSize: CGSize(width: width, height: height),
                                                     column: 5000, paperColumnHeight: 5000), [.bottom],
                           "an iPhone \(width)×\(height), any column")
        }
    }

    /// An iPad: all four on the owner's mini, Air 11 and Pro 13 (and the Pro 11) both ways; top and bottom in the 13-inch's
    /// ⅔ (678) and ½ (683) splits on its side; the bottom only in Slide Over and the narrow splits.
    func testIPadWindows() {
        for (width, height) in [(744, 1133), (1133, 744), (820, 1180), (1180, 820), (834, 1210), (1210, 834),
                                (1032, 1376), (1376, 1032)] as [(CGFloat, CGFloat)] {
            XCTAssertEqual(edges(isPad: true, width, height), all, "an iPad \(width)×\(height)")
        }
        for (width, height) in [(678, 1024), (683, 1032)] as [(CGFloat, CGFloat)] {
            XCTAssertEqual(edges(isPad: true, width, height), [.bottom, .top], "an iPad split \(width)×\(height)")
        }
        for (width, height) in [(320, 1024), (375, 1376), (512, 1376), (586, 820), (562, 744)] as [(CGFloat, CGFloat)] {
            XCTAssertEqual(edges(isPad: true, width, height), [.bottom], "a narrow iPad window \(width)×\(height)")
        }
    }

    /// The limits: a wide window (short side 600, `WindowClass.isWide`), a column of 700 and a column 460 tall under the
    /// header; a window not measured yet, or a value that is not finite, allows no more than the bottom (or no side).
    func testSideLimits() {
        let big = CGSize(width: 1032, height: 1376)
        func allowed(_ size: CGSize?, column: CGFloat = 1032, height: CGFloat = 1100) -> [PaletteEdge] {
            ToolbarLogic.allowedEdges(isPad: true, windowSize: size, column: column, paperColumnHeight: height)
        }
        XCTAssertEqual(ToolbarLogic.sideMinColumn, 700)
        XCTAssertEqual(ToolbarLogic.sideMinColumnHeight, 460)
        XCTAssertEqual(WindowClass.wideShortSide, 600)
        XCTAssertEqual(allowed(big, column: 700), all, "a 700 column takes the sides")
        XCTAssertEqual(allowed(big, column: 699.5), [.bottom, .top], "under 700: no sides")
        XCTAssertEqual(allowed(big, column: 678), [.bottom, .top], "678 (MT1)")
        XCTAssertEqual(allowed(big, height: 460), all, "a 460 column under the header takes the sides")
        XCTAssertEqual(allowed(big, height: 459.5), [.bottom, .top], "under 460: no sides")
        XCTAssertEqual(allowed(CGSize(width: 600, height: 900), column: 700), all, "a short side of 600 is wide")
        XCTAssertEqual(allowed(CGSize(width: 599.5, height: 1376)), [.bottom], "under 600: the bottom only")
        XCTAssertEqual(allowed(CGSize(width: 1376, height: 599.5)), [.bottom], "on its side too")
        XCTAssertEqual(allowed(nil), [.bottom], "not measured yet")
        XCTAssertEqual(allowed(CGSize(width: 0, height: 1376)), [.bottom])
        XCTAssertEqual(allowed(big, column: .nan), [.bottom, .top])
        XCTAssertEqual(allowed(big, height: .nan), [.bottom, .top])
        XCTAssertEqual(allowed(big, column: .infinity, height: .infinity), all)
        // The narrowed column of a side bar stays wide (`smallScreen` is under 600): 700 − 74 = 626.
        XCTAssertGreaterThanOrEqual(ToolbarLogic.sideMinColumn - ToolbarLogic.sideSlotWidth, 626)
        // Every answer is in [bottom, top, left, right]'s order, starts with the bottom and has the top whenever a side.
        for width in stride(from: CGFloat(300), through: 1400, by: 50) {
            for height in stride(from: CGFloat(300), through: 1400, by: 50) {
                for isPad in [false, true] {
                    let result = edges(isPad: isPad, width, height)
                    XCTAssertEqual(result.first, .bottom)
                    XCTAssertEqual(result, PaletteEdge.allCases.filter { result.contains($0) })
                    XCTAssertTrue(result == [.bottom] || result == [.bottom, .top] || result == all, "\(result)")
                    XCTAssertEqual(ToolbarLogic.showsGrip(.expanded, allowed: result), result.count >= 2)
                }
            }
        }
    }

    // MARK: effectiveEdge (§4.3, §4.10)

    func testEffectiveEdgeKeepsTheStoredOne() {
        let windows: [[PaletteEdge]] = [[.bottom], [.bottom, .top], all]
        for allowed in windows {
            for stored in PaletteEdge.allCases {
                let shown = ToolbarLogic.effectiveEdge(stored: stored, allowed: allowed)
                XCTAssertEqual(shown, allowed.contains(stored) ? stored : .bottom, "\(stored) in \(allowed)")
            }
        }
        // A left bar turned to a narrow window shows at the bottom; the stored value is the caller's and stays.
        let stored = PaletteEdge.left
        XCTAssertEqual(ToolbarLogic.effectiveEdge(stored: stored, allowed: [.bottom, .top]), .bottom)
        XCTAssertEqual(ToolbarLogic.effectiveEdge(stored: stored, allowed: all), .left, "back when allowed again")
        XCTAssertEqual(ToolbarLogic.effectiveEdge(stored: .top, allowed: []), .bottom)
    }

    // MARK: snapEdge (§4.7)

    /// A 1000 × 800 column at (0, 100): the middle (kept) is 250…750 × 300…700.
    private let column = CGRect(x: 0, y: 100, width: 1000, height: 800)

    private func snap(_ x: CGFloat, _ y: CGFloat, velocity: CGVector = .zero, allowed: [PaletteEdge]? = nil,
                      current: PaletteEdge = .bottom) -> PaletteEdge {
        ToolbarLogic.snapEdge(drop: CGPoint(x: x, y: y), velocity: velocity, frame: column, allowed: allowed ?? all,
                              current: current)
    }

    func testTheMiddleKeepsTheEdge() {
        XCTAssertEqual(ToolbarLogic.snapLookAhead, 0.15)
        XCTAssertEqual(ToolbarLogic.snapDeadZone, 0.25)
        for current in PaletteEdge.allCases {
            XCTAssertEqual(snap(500, 500, current: current), current, "the middle keeps \(current)")
            XCTAssertEqual(snap(260, 310, current: current), current, "inside the middle's corner")
            XCTAssertEqual(snap(740, 690, current: current), current)
        }
        // Just outside the middle: the nearest edge.
        XCTAssertEqual(snap(500, 299, current: .bottom), .top, "above the middle")
        XCTAssertEqual(snap(240, 500, current: .bottom), .left)
        XCTAssertEqual(snap(760, 500, current: .left), .right)
        XCTAssertEqual(snap(500, 710, current: .top), .bottom)
    }

    func testTheNearestEdge() {
        XCTAssertEqual(snap(500, 120), .top)
        XCTAssertEqual(snap(500, 890, current: .top), .bottom)
        XCTAssertEqual(snap(20, 500), .left)
        XCTAssertEqual(snap(980, 500), .right)
        XCTAssertEqual(snap(100, 250), .left, "left 100 is nearer than top 150")
        XCTAssertEqual(snap(200, 150), .top, "top 50 is nearer than left 200")
        // Outside the column: held inside it first.
        XCTAssertEqual(snap(-300, 500), .left)
        XCTAssertEqual(snap(1300, 500), .right)
        XCTAssertEqual(snap(500, -50), .top)
        XCTAssertEqual(snap(500, 2000, current: .left), .bottom)
    }

    /// The speed carries the drop 0.15 s ahead: a flick from the middle goes to the edge it was thrown at; a slow drift
    /// that stays in the middle keeps the edge.
    func testAFlickCarriesTheDrop() {
        XCTAssertEqual(snap(500, 500, velocity: CGVector(dx: 0, dy: -3000)), .top, "500 − 450 = 50 from the top")
        XCTAssertEqual(snap(500, 500, velocity: CGVector(dx: 4000, dy: 0)), .right, "1100, held at 1000")
        XCTAssertEqual(snap(500, 500, velocity: CGVector(dx: -4000, dy: 0), current: .right), .left)
        XCTAssertEqual(snap(500, 500, velocity: CGVector(dx: 0, dy: 1000), current: .left), .left, "650: still the middle")
        XCTAssertEqual(snap(100, 500, velocity: CGVector(dx: 6000, dy: 0), current: .left), .right,
                       "dropped by the left edge but thrown to the right")
        XCTAssertEqual(snap(500, 500, velocity: CGVector(dx: CGFloat.nan, dy: CGFloat.infinity), current: .left), .left,
                       "a speed that is not finite counts as none")
    }

    /// A disallowed edge is never chosen: a drop at the right of a window that allows the top and the bottom goes to the
    /// nearer of the two, and to the current one when they are as near.
    func testDisallowedEdges() {
        let topBottom: [PaletteEdge] = [.bottom, .top]
        XCTAssertEqual(snap(990, 200, allowed: topBottom), .top)
        XCTAssertEqual(snap(990, 800, allowed: topBottom, current: .top), .bottom)
        XCTAssertEqual(snap(990, 500, allowed: topBottom, current: .bottom), .bottom, "a tie keeps the current edge")
        XCTAssertEqual(snap(990, 500, allowed: topBottom, current: .top), .top, "a tie keeps the current edge")
        XCTAssertEqual(snap(10, 500, allowed: [.bottom]), .bottom)
        XCTAssertEqual(snap(500, 120, allowed: [.bottom], current: .bottom), .bottom)
        // A current edge the window does not allow (a caller's slip) is not kept, even in the middle.
        XCTAssertEqual(snap(500, 500, allowed: topBottom, current: .left), .bottom, "a tie of 400 and 400: bottom first")
        XCTAssertEqual(snap(500, 300, allowed: topBottom, current: .right), .top)
    }

    /// Ties: the current edge, then bottom, top, left, right.
    func testTies() {
        // The top-left corner: top 0 and left 0.
        XCTAssertEqual(snap(0, 100, current: .left), .left)
        XCTAssertEqual(snap(0, 100, current: .top), .top)
        XCTAssertEqual(snap(0, 100, current: .bottom), .top, "top before left")
        XCTAssertEqual(snap(0, 100, current: .right), .top)
        // The bottom-right corner: bottom 0 and right 0.
        XCTAssertEqual(snap(1000, 900, current: .right), .right)
        XCTAssertEqual(snap(1000, 900, current: .top), .bottom, "bottom before right")
        // The bottom-left corner without the bottom: left.
        XCTAssertEqual(snap(0, 900, allowed: [.top, .left, .right], current: .top), .left)
    }

    func testUnusableInput() {
        XCTAssertEqual(ToolbarLogic.snapEdge(drop: CGPoint(x: CGFloat.nan, y: 10), velocity: .zero, frame: column,
                                             allowed: all, current: .left), .left)
        XCTAssertEqual(ToolbarLogic.snapEdge(drop: CGPoint(x: 10, y: 10), velocity: .zero, frame: .zero,
                                             allowed: all, current: .top), .top)
        XCTAssertEqual(ToolbarLogic.snapEdge(drop: CGPoint(x: 10, y: 10), velocity: .zero, frame: .null,
                                             allowed: [.bottom, .top], current: .left), .bottom, "effectiveEdge")
        XCTAssertEqual(ToolbarLogic.snapEdge(drop: CGPoint(x: 10, y: 10), velocity: .zero, frame: column,
                                             allowed: [], current: .right), .right)
        // A frame given with a negative size is the same frame.
        let flipped = CGRect(x: 1000, y: 900, width: -1000, height: -800)
        XCTAssertEqual(ToolbarLogic.snapEdge(drop: CGPoint(x: 20, y: 500), velocity: .zero, frame: flipped,
                                             allowed: all, current: .bottom), .left)
    }

    // MARK: The drop's step (§4.7)

    func testPlacementChosenStoresOnTheOpenBarOnly() {
        XCTAssertEqual(ToolbarLogic.step(.expanded, on: .placementChosen),
                       ToolbarStep(mode: .expanded, storesPlacement: true))
        XCTAssertEqual(ToolbarLogic.step(.collapsed, on: .placementChosen), ToolbarStep(mode: .collapsed))
        XCTAssertEqual(ToolbarLogic.step(.peek, on: .placementChosen), ToolbarStep(mode: .peek))
        XCTAssertFalse(ToolbarStep(mode: .expanded).storesPlacement, "the new field is false by default")
        XCTAssertNil(ToolbarLogic.step(.expanded, on: .placementChosen).storeCollapsed)
        XCTAssertFalse(ToolbarLogic.step(.expanded, on: .placementChosen).flipsEdge)
        // No other event writes the edge.
        let events: [ToolbarEvent] = [.collapseTapped, .penDown, .dockToolTapped, .dockUndoTapped, .wentToBackground,
                                      .pinChosen, .moveEdgeChosen, .placementChosen, .other]
        var stores: [String] = []
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            for event in events where ToolbarLogic.step(mode, on: event).storesPlacement {
                stores.append("\(mode) \(event)")
            }
        }
        XCTAssertEqual(stores, ["expanded placementChosen"])
        // 1.4's rows are the same, the new field false.
        XCTAssertEqual(ToolbarLogic.step(.expanded, on: .collapseTapped), ToolbarStep(mode: .collapsed, storeCollapsed: true))
        XCTAssertEqual(ToolbarLogic.step(.collapsed, on: .moveEdgeChosen), ToolbarStep(mode: .collapsed, flipsEdge: true))
        XCTAssertEqual(ToolbarLogic.step(.collapsed, on: .pinChosen), ToolbarStep(mode: .expanded, storeCollapsed: false))
    }

    // MARK: Slots and paddings (§4.4, §4.5, §4.9)

    func testSlotsAndPaddings() {
        XCTAssertEqual(ToolbarLogic.sideSlotWidth, 74)
        XCTAssertEqual(ToolbarLogic.topSlotHeight, 74)
        XCTAssertEqual(ToolbarLogic.verticalBarWidth, 60)
        XCTAssertEqual(ToolbarLogic.expandedBottomGap, 8)
        XCTAssertEqual(ToolbarLogic.slotOuterPadding + ToolbarLogic.verticalBarWidth + ToolbarLogic.slotPaperGap, 74)
        XCTAssertEqual(ToolbarLogic.slotOuterPadding + ToolbarLogic.barHeight + ToolbarLogic.slotPaperGap, 74)
        XCTAssertEqual(2 * ToolbarLogic.Column.sidePadding + ToolbarLogic.Column.width, ToolbarLogic.verticalBarWidth)
        // A bottom bar with a grip takes 74 pt as 1.4's (8 + 60 + 6; 1.4's 8 was the inset's spacing, measured).
        XCTAssertEqual(ToolbarLogic.expandedBottomGap + ToolbarLogic.barHeight + ToolbarLogic.bottomPadding, 74)
        // 1.4's numbers do not change (InkCanvasSpanTests reads dockClearance).
        XCTAssertEqual(ToolbarLogic.dockClearance, 60)
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.expanded), 8)
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.collapsed), 62)
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.peek), 74)
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.expanded), 0)
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.collapsed), 60)
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.peek), 60)
    }

    func testToastSideInset() {
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            for edge in PaletteEdge.allCases {
                let expected: CGFloat = mode == .expanded && (edge == .left || edge == .right) ? 74 : 0
                XCTAssertEqual(ToolbarLogic.toastSideInset(mode, edge: edge), expected, "\(mode) \(edge)")
            }
        }
    }

    // MARK: The stored value (§4.10)

    func testStoredEdge() {
        XCTAssertEqual(PaletteEdge.allCases, all)
        XCTAssertEqual(all.map(\.rawValue), ["bottom", "top", "left", "right"])
        for edge in all {
            XCTAssertEqual(PaletteEdge(stored: edge.rawValue), edge)
        }
        for unknown in [nil, "", "Bottom", "TOP", " left", "leading", "trailing", "centre", "1"] as [String?] {
            XCTAssertEqual(PaletteEdge(stored: unknown), .bottom, "\(String(describing: unknown)) → bottom")
        }
        XCTAssertEqual(all.filter(\.isSide), [.left, .right])
        XCTAssertEqual(PaletteEdge.left.dockEdge, .leading, "a left drop writes the bottom-left dock")
        XCTAssertEqual(PaletteEdge.right.dockEdge, .trailing)
        XCTAssertNil(PaletteEdge.top.dockEdge)
        XCTAssertNil(PaletteEdge.bottom.dockEdge)
    }

    // MARK: Geometry (§4.5, §4.7)

    /// The bars' frames in a 1032 × 1200 column at (0, 100): the bottom bar is 1.4's (12 on each side, 6 above the safe
    /// area), the top bar 6 under the notices, the side bars 6 from the side, 60 wide.
    func testBarFrames() {
        let box = CGRect(x: 0, y: 100, width: 1032, height: 1200)
        XCTAssertEqual(ToolbarLogic.barFrame(.bottom, in: box), CGRect(x: 12, y: 1234, width: 1008, height: 60))
        XCTAssertEqual(ToolbarLogic.barFrame(.top, in: box), CGRect(x: 12, y: 106, width: 1008, height: 60))
        XCTAssertEqual(ToolbarLogic.barFrame(.left, in: box), CGRect(x: 6, y: 106, width: 60, height: 1188))
        XCTAssertEqual(ToolbarLogic.barFrame(.right, in: box), CGRect(x: 966, y: 106, width: 60, height: 1188))
        // Each bar leaves 8 to the paper: its slot is 74.
        XCTAssertEqual(ToolbarLogic.barFrame(.top, in: box).maxY + ToolbarLogic.slotPaperGap - box.minY, 74)
        XCTAssertEqual(box.maxX - (ToolbarLogic.barFrame(.right, in: box).minX - ToolbarLogic.slotPaperGap), 74)
        XCTAssertEqual(ToolbarLogic.barFrame(.left, in: box).maxX + ToolbarLogic.slotPaperGap - box.minX, 74)
        XCTAssertEqual(box.maxY - (ToolbarLogic.barFrame(.bottom, in: box).minY - ToolbarLogic.expandedBottomGap), 74)
        // Too small a column gives empty bars, not negative ones.
        XCTAssertEqual(ToolbarLogic.barFrame(.top, in: CGRect(x: 0, y: 0, width: 10, height: 5)).width, 0)
        XCTAssertEqual(ToolbarLogic.barFrame(.left, in: CGRect(x: 0, y: 0, width: 10, height: 5)).height, 0)
    }

    /// The grip: 120 × 16 (14 × 120 on a side), on the bar's inner edge, half over the gap to the paper; its mark over the
    /// bar's padding only.
    func testGripGeometry() {
        XCTAssertEqual(ToolbarLogic.gripSize(for: .bottom), CGSize(width: 120, height: 16))
        XCTAssertEqual(ToolbarLogic.gripSize(for: .top), CGSize(width: 120, height: 16))
        XCTAssertEqual(ToolbarLogic.gripSize(for: .left), CGSize(width: 14, height: 120))
        XCTAssertEqual(ToolbarLogic.gripSize(for: .right), CGSize(width: 14, height: 120))
        let wide = CGRect(x: 12, y: 1000, width: 1008, height: 60)
        let tall = CGRect(x: 6, y: 106, width: 60, height: 1188)
        XCTAssertEqual(ToolbarLogic.gripFrame(for: .bottom, bar: wide), CGRect(x: 456, y: 992, width: 120, height: 16))
        XCTAssertEqual(ToolbarLogic.gripFrame(for: .top, bar: wide), CGRect(x: 456, y: 1052, width: 120, height: 16))
        XCTAssertEqual(ToolbarLogic.gripFrame(for: .left, bar: tall), CGRect(x: 60, y: 640, width: 14, height: 120))
        XCTAssertEqual(ToolbarLogic.gripFrame(for: .right, bar: tall), CGRect(x: -2, y: 640, width: 14, height: 120))
        // The bottom bar's grip: 8 over the gap, 8 over the bar's own padding (above its 44 pt buttons).
        let bottomGrip = ToolbarLogic.gripFrame(for: .bottom, bar: wide)
        XCTAssertEqual(bottomGrip.maxY - wide.minY, 8)
        XCTAssertEqual(wide.minY - bottomGrip.minY, ToolbarLogic.expandedBottomGap)

        for edge in PaletteEdge.allCases {
            let size = ToolbarLogic.gripSize(for: edge)
            let mark = ToolbarLogic.gripMarkFrame(for: edge, in: size)
            XCTAssertTrue(CGRect(origin: .zero, size: size).contains(mark), "\(edge): the mark is inside the grip")
            XCTAssertEqual(max(mark.width, mark.height), 36)
            XCTAssertEqual(min(mark.width, mark.height), 5)
            XCTAssertEqual(mark.width > mark.height, !edge.isSide, "\(edge): the mark lies along the edge")
        }
        XCTAssertEqual(ToolbarLogic.gripMarkFrame(for: .bottom, in: CGSize(width: 120, height: 16)),
                       CGRect(x: 42, y: 9.5, width: 36, height: 5), "the lower half: over the bar")
        XCTAssertEqual(ToolbarLogic.gripMarkFrame(for: .top, in: CGSize(width: 120, height: 16)),
                       CGRect(x: 42, y: 1.5, width: 36, height: 5), "the upper half: over the bar")
        XCTAssertEqual(ToolbarLogic.gripMarkFrame(for: .left, in: CGSize(width: 14, height: 120)),
                       CGRect(x: 0.5, y: 42, width: 5, height: 36), "the left 6: over the bar")
        XCTAssertEqual(ToolbarLogic.gripMarkFrame(for: .right, in: CGSize(width: 14, height: 120)),
                       CGRect(x: 8.5, y: 42, width: 5, height: 36), "the right 6: over the bar")
        // The grip only on the open bar with two edges or more.
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            XCTAssertFalse(ToolbarLogic.showsGrip(mode, allowed: [.bottom]))
            XCTAssertEqual(ToolbarLogic.showsGrip(mode, allowed: [.bottom, .top]), mode == .expanded)
            XCTAssertEqual(ToolbarLogic.showsGrip(mode, allowed: all), mode == .expanded)
        }
    }

    // MARK: VoiceOver (§4.11)

    func testVoiceOverTexts() {
        XCTAssertEqual(ToolbarLogic.gripAccessibilityLabel, "ツールバーを動かす")
        XCTAssertEqual(ToolbarLogic.gripAccessibilityHint, "上下左右の端へ移せます")
        XCTAssertEqual(ToolbarLogic.moveToTitle(.top), "上へ移す")
        XCTAssertEqual(ToolbarLogic.moveToTitle(.bottom), "下へ移す")
        XCTAssertEqual(ToolbarLogic.moveToTitle(.left), "左へ移す")
        XCTAssertEqual(ToolbarLogic.moveToTitle(.right), "右へ移す")
        XCTAssertEqual(ToolbarLogic.moveTargets(allowed: all, current: .bottom), [.top, .left, .right])
        XCTAssertEqual(ToolbarLogic.moveTargets(allowed: all, current: .left), [.bottom, .top, .right])
        XCTAssertEqual(ToolbarLogic.moveTargets(allowed: [.bottom, .top], current: .top), [.bottom])
        XCTAssertEqual(ToolbarLogic.moveTargets(allowed: [.bottom], current: .bottom), [])
    }
}
