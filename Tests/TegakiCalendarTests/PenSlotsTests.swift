import Layout
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.1–§3.3, §6.1, 0f-6–0f-8): the six pen dots of this device (`toolbar.penSlots`): read back
/// always as six colours, none twice, whatever was stored; the pen the toolbar and the launch take is looked up in those dots
/// (one not there is the first dot's); the twelve colours of the panel and their names. Fails with the gate looking in
/// `penColors` (mutation MC1) or with the dots not repaired (MC2).
final class PenSlotsTests: XCTestCase {
    private let first = ["#1f2937", "#2563eb", "#dc2626", "#16a34a", "#ea580c", "#7c3aed"]
    private let brown = "#92400e"
    private let gray = "#6b7280"

    func testTheFirstSixAndTheTwelve() {
        XCTAssertEqual(ToolbarPalette.penSlotsKey, "toolbar.penSlots")
        XCTAssertEqual(ToolbarPalette.defaultSlots, first, "the first six are the six of 1.4.1, in their order")
        XCTAssertEqual(ToolbarPalette.penColors.map(\.hex), first, "penColors does not change")
        XCTAssertEqual(ToolbarPalette.panelColors.map(\.hex),
                       first + ["#92400e", "#6b7280", "#db2777", "#0284c7", "#166534", "#1e40af"])
        XCTAssertEqual(ToolbarPalette.panelColors.map(\.name),
                       ["黒", "青", "赤", "緑", "オレンジ", "紫", "茶", "グレー", "ピンク", "水色", "深緑", "紺"])
        XCTAssertEqual(Set(ToolbarPalette.panelColors.map(\.hex)).count, 12, "twelve colours")
        XCTAssertEqual(ToolbarPalette.markerColors.count, 4, "the marker keeps its four")
    }

    // MARK: slots(stored:)

    func testNothingStoredIsTheFirstSix() {
        XCTAssertEqual(ToolbarPalette.slots(stored: nil), first)
        XCTAssertEqual(ToolbarPalette.slots(stored: ""), first)
    }

    func testAStoredTextIsReadBack() {
        let mine = [brown, gray, "#db2777", "#0284c7", "#166534", "#1e40af"]
        XCTAssertEqual(ToolbarPalette.slots(stored: mine.joined(separator: ",")), mine)
        XCTAssertEqual(ToolbarPalette.storedSlots(mine), mine.joined(separator: ","))
        XCTAssertEqual(ToolbarPalette.slots(stored: ToolbarPalette.storedSlots(mine)), mine, "the round trip")
        XCTAssertEqual(ToolbarPalette.slots(stored: ToolbarPalette.storedSlots(first)), first)
        let other = [brown] + first.dropFirst()
        XCTAssertEqual(ToolbarPalette.slots(stored: ToolbarPalette.storedSlots(other)), other)
    }

    func testNotSixPiecesIsTheFirstSix() {
        XCTAssertEqual(ToolbarPalette.slots(stored: first.prefix(5).joined(separator: ",")), first, "five")
        XCTAssertEqual(ToolbarPalette.slots(stored: (first + [brown]).joined(separator: ",")), first, "seven")
        XCTAssertEqual(ToolbarPalette.slots(stored: brown), first, "one")
        XCTAssertEqual(ToolbarPalette.slots(stored: ",,,,,,"), first, "seven empty pieces")
    }

    func testAnUnreadablePieceIsThatDotsFirstColour() {
        let stored = [brown, "not a colour", "#12345", "", "#0284c7", "#1e40af"].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: stored), [brown, first[1], first[2], first[3], "#0284c7", "#1e40af"])
    }

    func testUpperCaseAndShortFormsAreNormalized() {
        let stored = ["#92400E", "#6B7280", "#abc", "#0284C7", "#166534", "#1E40AF"].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: stored), [brown, gray, "#aabbcc", "#0284c7", "#166534", "#1e40af"])
    }

    func testTwoAlikeAreRepaired() {
        // The second brown is its dot's first colour (青).
        let two = [brown, brown, "#db2777", "#0284c7", "#166534", "#1e40af"].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: two), [brown, first[1], "#db2777", "#0284c7", "#166534", "#1e40af"])
        // Three alike: the second is 青 (its first colour), the third 赤 (its own).
        let three = [brown, brown, brown, "#0284c7", "#166534", "#1e40af"].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: three), [brown, first[1], first[2], "#0284c7", "#166534", "#1e40af"])
        // A dot whose first colour an earlier dot has: the first of the twelve no earlier dot has.
        let taken = [first[1], first[1], first[0], first[2], first[3], first[4]].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: taken), [first[1], first[0], first[2], first[3], first[4], first[5]],
                       "dot 2: 青 again and its own 青 taken → 黒, the first of the twelve free; then each its own first colour")
        // Every dot alike.
        let same = Array(repeating: "#1f2937", count: 6).joined(separator: ",")
        let repaired = ToolbarPalette.slots(stored: same)
        XCTAssertEqual(repaired, first)
        // The same colour in two forms.
        let forms = ["#aabbcc", "#ABC", "#abc", "#0284c7", "#166534", "#1e40af"].joined(separator: ",")
        XCTAssertEqual(ToolbarPalette.slots(stored: forms), ["#aabbcc", first[1], first[2], "#0284c7", "#166534", "#1e40af"])
    }

    /// Whatever is stored, six colours and none twice.
    func testAlwaysSixNeverTwiceAlike() {
        let pieces = ["#1f2937", "#2563eb", "#92400e", "#abc", "#AABBCC", "", "x", "#dc2626", "#6b7280", "#0284c7"]
        var seed: UInt64 = 0x2026_1125
        func next() -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int(seed >> 33)
        }
        for _ in 0..<500 {
            let count = 4 + next() % 4
            let stored = (0..<count).map { _ in pieces[next() % pieces.count] }.joined(separator: ",")
            let slots = ToolbarPalette.slots(stored: stored)
            XCTAssertEqual(slots.count, 6, stored)
            XCTAssertEqual(Set(slots).count, 6, stored)
            XCTAssertTrue(slots.allSatisfy { InkColors.normalized($0) == $0 }, stored)
        }
    }

    // MARK: pen(colorHex:width:slots:) and rememberedPen (§3.3)

    func testThePenIsLookedUpInTheDots() {
        let mine = [brown] + first.dropFirst()
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: 6, slots: mine), InkStyle(tool: .pen, colorHex: brown, width: 6),
                       "a dot's colour is the pen's")
        XCTAssertEqual(ToolbarPalette.pen(colorHex: "#92400E", width: 2, slots: mine).colorHex, brown, "either case")
        XCTAssertEqual(ToolbarPalette.pen(colorHex: first[0], width: 3.5, slots: mine), InkStyle(tool: .pen, colorHex: brown, width: 3.5),
                       "黒 is no dot any more: the first dot's colour")
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: 3.5).colorHex, first[0],
                       "with the first six (the default) brown is on no dot: 黒, as 1.4.1")
        XCTAssertEqual(ToolbarPalette.pen(colorHex: "#123456", width: 2, slots: mine), InkStyle(tool: .pen, colorHex: brown, width: 2))
        XCTAssertEqual(ToolbarPalette.pen(colorHex: nil, width: nil, slots: mine), InkStyle(tool: .pen, colorHex: brown, width: 3.5))
        // The width's rule is 1.4.1's.
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: 5, slots: mine).width, 3.5)
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: .nan, slots: mine).width, 3.5)
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: 18, slots: mine).width, 3.5)
        XCTAssertEqual(ToolbarPalette.pen(colorHex: brown, width: 2, slots: mine).width, 2)
        // Every first colour on the first six, as 1.4.1.
        for hex in first {
            XCTAssertEqual(ToolbarPalette.pen(colorHex: hex, width: 3.5).colorHex, hex)
        }
    }

    func testRememberedPenReadsTheDots() throws {
        let suite = "test-pen-slots-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(brown, forKey: ToolbarPalette.penColorKey)
        defaults.set(6.0, forKey: ToolbarPalette.penWidthKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: first[0], width: 6),
                       "brown on no dot (nothing stored): the first dot, 黒")
        defaults.set(ToolbarPalette.storedSlots([gray, brown] + first.dropFirst(2)), forKey: ToolbarPalette.penSlotsKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: brown, width: 6), "茶 on dot 2, 茶")
        defaults.set(first[0], forKey: ToolbarPalette.penColorKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).colorHex, gray, "黒 on no dot: the first dot, グレー")
        defaults.set("garbage", forKey: ToolbarPalette.penSlotsKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).colorHex, first[0], "broken dots read as the first six")
        // Dots stored as no text at all (D1b's review, nit 6): the first six too. The pen 茶 is then on no dot: the first dot, 黒.
        defaults.set(brown, forKey: ToolbarPalette.penColorKey)
        defaults.set(5, forKey: ToolbarPalette.penSlotsKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).colorHex, first[0], "a number for the dots: the first six")
        defaults.set(["#92400e"], forKey: ToolbarPalette.penSlotsKey)
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).colorHex, first[0], "a list for the dots: the first six")
    }

    // MARK: colorName (§3.3)

    func testTheNames() {
        let names = ["#1f2937": "黒", "#2563eb": "青", "#dc2626": "赤", "#16a34a": "緑", "#ea580c": "オレンジ", "#7c3aed": "紫",
                     "#92400e": "茶", "#6b7280": "グレー", "#db2777": "ピンク", "#0284c7": "水色", "#166534": "深緑", "#1e40af": "紺",
                     "#fde047": "黄", "#f9a8d4": "ピンク", "#86efac": "緑", "#93c5fd": "水色"]
        for (hex, name) in names {
            XCTAssertEqual(ToolbarPalette.colorName(hex), name, hex)
            XCTAssertEqual(ToolbarPalette.colorName(hex.uppercased()), name, hex)
        }
        XCTAssertEqual(ToolbarPalette.colorName("#0a7e8c"), "その他の色", "a colour of 「その他の色…」")
        XCTAssertEqual(ToolbarPalette.colorName("#000000"), "その他の色")
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(InkStyle(tool: .pen, colorHex: brown, width: 3.5))).accessibilityValue, "ペン・茶・中")
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(InkStyle(tool: .pen, colorHex: "#0a7e8c", width: 6))).accessibilityValue,
                       "ペン・その他の色・太")
    }

    func testTheDotIdentifiers() {
        XCTAssertEqual((0..<6).map(ToolbarPalette.swatchIdentifier),
                       ["toolbar.swatch.0", "toolbar.swatch.1", "toolbar.swatch.2", "toolbar.swatch.3", "toolbar.swatch.4", "toolbar.swatch.5"])
    }
}
