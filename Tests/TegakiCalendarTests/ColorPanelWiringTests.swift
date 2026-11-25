import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.6, §3.7, §5.6, §6.1, 0f-11, 0f-13, 0f-36; role S): the screen's wires of the pen
/// colour panel, read from the source in code only (`WeekMemoSpanTests.codeOnly`, every run of spaces one space): the screen's
/// View is not run by XCTest (C3-M3). The one `ToolbarView(` gets the panel before `axis:` (so 1.4.1's guarded text `axis: axis,
/// move: paletteMoveButton )` stays whole); the guarded counts of 1.4.1 and 1.3 do not move; the picker counts as a sheet (after
/// the age range's); the panel's closings are modifiers of their own (`colorPanelLayer`), none in the bodies of `sheetsChanged`,
/// `penDown`, `toolbarEvent`, `placePalette`, `paletteMoveChosen` or `paletteMoveButtonChose`; the window's watch is a `@State`,
/// put on the window when the panel opens and taken off when it closes, and closes it on a touch outside; the picker's colour
/// goes to the picker's dot. Fails with the watch never put on the window (mutation MS1).
@MainActor
final class ColorPanelWiringTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func code(_ path: String) throws -> String {
        let url = Self.repository.appendingPathComponent(path)
        return String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func count(_ text: String, in code: String) -> Int {
        code.components(separatedBy: text).count - 1
    }

    /// The body of the declaration that starts with `head` (which ends with its "{"), to its matching "}".
    private func body(of head: String, in code: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "no \(head)", file: file, line: line)
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("\(head) does not end", file: file, line: line)
        return ""
    }

    func testTheOneToolbarGetsThePanelBeforeTheAxis() throws {
        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        XCTAssertEqual(count("ToolbarView(", in: screen), 1, "one bar for every slot and peek")
        XCTAssertEqual(count("allowFinger: allowFingerBinding,", in: screen), 2)
        XCTAssertEqual(count("colorPanel: ColorPanelHook(openSlot: $colorPanelSlot), axis: axis, move: paletteMoveButton )", in: screen), 1)
        XCTAssertEqual(count("axis: axis, move: paletteMoveButton )", in: screen), 1, "1.4.1's guarded text whole")

        let toolbar = try code("Sources/TegakiCalendar/Views/ToolbarView.swift")
        XCTAssertEqual(count("var eraserReturnsTo: CanvasTool? = nil var colorPanel: ColorPanelHook? = nil var axis: Axis = .horizontal",
                             in: toolbar), 1, "declared between eraserReturnsTo and axis (the memberwise init's order)")
    }

    func testTheGuardedCountsStay() throws {
        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        XCTAssertEqual(count("guide.close()", in: screen), 3)
        XCTAssertEqual(count("guide.dismiss()", in: screen), 3)
        XCTAssertEqual(count("{ paletteMenuShown = false }", in: screen), 2)
        XCTAssertEqual(count("toolbarEvent(.placementChosen)", in: screen), 1)
        XCTAssertEqual(count("placePalette(on: edge)", in: screen), 2)
        XCTAssertFalse(screen.contains("$allowFinger"))
    }

    func testThePickerIsASheet() throws {
        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        let sheets = try body(of: "private var sheetIsUp: Bool {", in: screen)
        XCTAssertTrue(sheets.hasSuffix("|| ageRangeAsking || colorPickerShown "), "after the age range's: \(sheets)")
        XCTAssertEqual(count(".sheet(isPresented: $colorPickerShown, onDismiss: { colorPickerClosed() }) { "
                             + "ColorPickerSheet(initialHex: colorPickerInitialHex, onPick: { colorPicked($0) }, onDone: { colorPickerClosed() }) }",
                             in: screen), 1, "the picker's every close ends it")
        let closed = try body(of: "private func colorPickerClosed() {", in: screen)
        XCTAssertEqual(closed, " if colorPickerShown { colorPickerShown = false } if colorPickerSlot != nil { colorPickerSlot = nil } ")
        let picked = try body(of: "private func colorPicked(_ hex: String) {", in: screen)
        XCTAssertTrue(picked.contains("ColorPanelLogic.choose(hex, slot: colorPickerSlot ?? 0, slots: ColorPanelStore.slots())"),
                      "the picker's dot: \(picked)")
        let open = try body(of: "private func openColorPicker(from slot: Int) {", in: screen)
        XCTAssertEqual(open, " colorPickerSlot = slot closeColorPanel() colorPickerShown = true ", "the dot kept, the panel closed, then the picker")
    }

    func testTheClosingsAreTheirOwn() throws {
        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        for head in ["private func sheetsChanged() {", "private func penDown() {", "private func toolbarEvent(_ event: ToolbarEvent) {",
                     "private func placePalette(on edge: PaletteEdge) {", "private func paletteMoveChosen(_ edge: PaletteEdge) {",
                     "private func paletteMoveButtonChose(_ edge: PaletteEdge) {", "private func scenePhaseChanged() {"] {
            let text = try body(of: head, in: screen)
            XCTAssertFalse(text.contains("colorPanelSlot"), head)
            XCTAssertFalse(text.contains("closeColorPanel"), head)
        }
        for modifier in [".onChange(of: sheetIsUp) { if sheetIsUp { closeColorPanel() } }",
                         ".onChange(of: scenePhase) { if scenePhase != .active { closeColorPanel() } }",
                         ".onChange(of: windowSize) { closeColorPanel() }",
                         ".onChange(of: toolbarMode) { closeColorPanel() }",
                         ".onChange(of: paletteEdge) { closeColorPanel() }",
                         ".onChange(of: paletteDragging) { if paletteDragging { closeColorPanel() } }",
                         ".onChange(of: paletteMenuShown) { if paletteMenuShown { closeColorPanel() } }",
                         ".onChange(of: tool) { if ToolbarLogic.kind(of: tool) != .pen { closeColorPanel() } }"] {
            XCTAssertEqual(count(modifier, in: screen), 1, modifier)
        }
        XCTAssertEqual(count("private func closeColorPanel() { if colorPanelSlot != nil { colorPanelSlot = nil } }", in: screen), 1)
        // 1.3's and 1.4.1's own watches stay as they were.
        XCTAssertEqual(count(".onChange(of: sheetIsUp) { sheetsChanged() }", in: screen), 1)
        XCTAssertEqual(count(".onChange(of: scenePhase) { scenePhaseChanged() }", in: screen), 1)
        XCTAssertEqual(count(".onChange(of: tool) { if case .ink = tool { lastInkTool = tool } }", in: screen), 1)
        XCTAssertEqual(count(".onChange(of: paletteEdge) { logPalette() }", in: screen), 1)
        XCTAssertEqual(count(".onChange(of: sheetIsUp) { if sheetIsUp { cancelPaletteDrag() } }", in: screen), 1)
        // The layer lies over the arranged column.
        XCTAssertEqual(count("presented(watchedFurther(watched(colorPanelLayer(arranged))))", in: screen), 1)
        XCTAssertEqual(count(".overlayPreferenceValue(ColorPanelAnchorKey.self) { anchor in ColorPanelHost(anchor: anchor, "
                             + "openSlot: $colorPanelSlot, edge: paletteEdge, tool: toolBinding, watch: colorPanelWatch,", in: screen), 1)
    }

    func testTheWatchFollowsThePanel() throws {
        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        XCTAssertEqual(count("@State private var colorPanelWatch = ColorPanelWatch()", in: screen), 1, "a @State, not a let")
        XCTAssertEqual(count(".onChange(of: colorPanelSlot) { if colorPanelSlot != nil, let window = paletteRoom.window { "
                             + "colorPanelWatch.attach(to: window) } else { colorPanelWatch.detach() } }", in: screen), 1,
                       "on the window while the panel is open")
        XCTAssertEqual(count("colorPanelWatch.attach(to:", in: screen), 1)
        XCTAssertEqual(count("colorPanelWatch.onOutsideTouch = { closeColorPanel() }", in: screen), 1, "a touch outside closes it")
    }
}
