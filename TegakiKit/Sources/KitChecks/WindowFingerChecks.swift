// KitChecks: the window's size and 「指でも書く」 on a phone, 1.4 (docs/M7D_CONTRACT.md §2.1, §4.3, §4.4, §4.7, §4.8, §6; section
// "window & finger (1.4)"). main.swift calls `runWindowFingerChecks()` right after `runDuoChecks()`; it uses main.swift's
// `section`, `check`, `checkEqual`, `passed` and `failures`.
//
// `WindowClass` decides the look by the window's size (the opening page, the sheet's shape, the overview cap) and
// `FingerDefault` decides whether the app turns 「指でも書く」 off (the Pencil P and the hinge H, never the window). Both are pure,
// so their mutations are checked here with `swift run KitChecks` on a Mac, not on CI (§3.10, §6: M-w1, M-w2, M-f1 … M-f7). The
// expectations are literals: sizes in points (today's iPhones, the Duo's estimates of docs/m7d/CODE_SURVEY.md §3.2) and the
// table of §4.8 written out row by row, never read back from the code under test.
import Foundation
import CoreGraphics
import Layout

func runWindowFingerChecks() {
    section("window & finger (1.4)")
    let start = passed + failures.count
    windowClassChecks()
    fingerDefaultChecks()
    print("   \(passed + failures.count - start) checks in this section")
}

// MARK: - WindowClass (§4.3, §4.4, §4.7)

private func size(_ w: CGFloat, _ h: CGFloat) -> CGSize { CGSize(width: w, height: h) }

/// The window sizes (pt, portrait) of the iPhones iOS 17 and later run on: SE (2nd, 3rd), mini / X / 11 Pro, 12 – 14 and 16e,
/// 14 Pro – 16, 16 Pro – 17 Pro (iPhone 17), XR / 11 / XS Max, Air, 12 – 14 Pro Max / Plus, 14 Pro Max – 16 Plus, 16 Pro Max –
/// 17 Pro Max. Every short side is 440 or less.
private let iPhoneWindows: [CGSize] = [
    size(375, 667), size(375, 812), size(390, 844), size(393, 852), size(402, 874), size(414, 896), size(420, 912),
    size(428, 926), size(430, 932), size(440, 956),
]

private func windowClassChecks() {
    checkEqual(WindowClass.wideShortSide, 600, "window: a wide window's short side is 600 or more (the header's one-row width)")

    // isWide: by the short side; unmeasured sizes are not wide.
    let wide: [(String, CGSize?, Bool)] = [
        ("iPhone 17 portrait", size(402, 874), false), ("iPhone 17 landscape", size(874, 402), false),
        ("iPhone 17 Pro Max portrait", size(440, 956), false), ("iPhone 17 Pro Max landscape", size(956, 440), false),
        ("Duo inner A portrait (estimate)", size(669, 951), true), ("Duo inner A landscape (estimate)", size(951, 669), true),
        ("Duo inner B portrait (estimate)", size(626, 890), true), ("Duo inner B landscape (estimate)", size(890, 626), true),
        ("Duo outer portrait (estimate)", size(466, 678), false), ("Duo outer landscape (estimate)", size(678, 466), false),
        ("a short side of 599.9", size(599.9, 900), false), ("a short side of 599.9, landscape", size(900, 599.9), false),
        ("a square of 600", size(600, 600), true), ("a short side of 600, landscape", size(900, 600), true),
        ("nil", nil, false), ("zero", .zero, false), ("a width of 0", size(0, 951), false), ("a height of 0", size(669, 0), false),
        ("a negative width", size(-669, 951), false), ("a negative height", size(669, -951), false),
        ("a negative size", size(-951, -669), false),
        ("a NaN width", size(.nan, 951), false), ("a NaN height", size(669, .nan), false),
        ("an infinite width", size(.infinity, 951), false), ("an infinite height", size(669, .infinity), false),
        ("an infinite size", size(.infinity, .infinity), false), ("a negative infinite width", size(-.infinity, 951), false),
    ]
    for (name, s, expected) in wide {
        checkEqual(WindowClass.isWide(s), expected, "window: \(name) is \(expected ? "" : "not ")wide")
        // The overview cap is the other side of it (unmeasured sizes keep 1.3's cap).
        checkEqual(WindowClass.capsOverview(windowSize: s), !expected, "window: \(name) \(expected ? "has no" : "has the") overview cap")
    }
    for w in iPhoneWindows {
        for s in [w, size(w.height, w.width)] {
            checkEqual(WindowClass.isWide(s), false, "window: the iPhone window \(s) is not wide")
        }
    }

    // openingKind: what is stored wins; an iPad opens the month; a phone by the short side once measured; nil before.
    let opening: [(String, PageKind?, Bool, CGSize?, PageKind?)] = [
        ("stored day on a phone, wide", .day, false, size(669, 951), .day),
        ("stored week on a phone, wide", .week, false, size(951, 669), .week),
        ("stored month on a phone, narrow", .month, false, size(402, 874), .month),
        ("stored year on a phone, unmeasured", .year, false, nil, .year),
        ("stored day on a phone, zero", .day, false, .zero, .day),
        ("stored week on an iPad", .week, true, size(1032, 1376), .week),
        ("stored day on an iPad, unmeasured", .day, true, nil, .day),
        ("an iPad, unmeasured", nil, true, nil, .month),
        ("an iPad 13", nil, true, size(1032, 1376), .month),
        ("an iPad 13 landscape", nil, true, size(1376, 1032), .month),
        ("an iPad in a narrow window", nil, true, size(402, 874), .month),
        ("an iPad, zero", nil, true, .zero, .month),
        ("iPhone 17 portrait", nil, false, size(402, 874), .week),
        ("iPhone 17 landscape (by the short side, not the width)", nil, false, size(874, 402), .week),
        ("iPhone 17 Pro Max portrait", nil, false, size(440, 956), .week),
        ("iPhone 17 Pro Max landscape", nil, false, size(956, 440), .week),
        ("Duo inner A portrait", nil, false, size(669, 951), .month),
        ("Duo inner A landscape", nil, false, size(951, 669), .month),
        ("Duo inner B portrait", nil, false, size(626, 890), .month),
        ("Duo inner B landscape", nil, false, size(890, 626), .month),
        ("Duo outer portrait", nil, false, size(466, 678), .week),
        ("Duo outer landscape", nil, false, size(678, 466), .week),
        ("a phone, unmeasured", nil, false, nil, nil),
        ("a phone, zero", nil, false, .zero, nil),
        ("a phone, a height of 0", nil, false, size(669, 0), nil),
        ("a phone, a NaN width", nil, false, size(.nan, 951), nil),
        ("a phone, a negative size", nil, false, size(-669, -951), nil),
        ("a phone, an infinite height", nil, false, size(669, .infinity), nil),
    ]
    for (name, stored, isPad, s, expected) in opening {
        checkEqual(WindowClass.openingKind(stored: stored, isPad: isPad, windowSize: s), expected,
                   "window: the opening kind of \(name) is \(expected.map { $0.rawValue } ?? "not decided yet")")
    }
    for w in iPhoneWindows {
        for s in [w, size(w.height, w.width)] {
            checkEqual(WindowClass.openingKind(stored: nil, isPad: false, windowSize: s), .week, "window: the iPhone window \(s) opens the week")
        }
    }

    // usesFormSheet: an iPad always; a wide window only when formSheetOnWide (false: 1.4 D1c kept §4.4's default, since duo.yml's
    // run 44696154794 took road 3 and shot no inner screen; a road 1 or 2 run whose two sheet checks pass changes it with this row).
    checkEqual(WindowClass.formSheetOnWide, false, "window: formSheetOnWide is false (§4.4: road 3, the inner screen not shot, run 44696154794)")
    let sheets: [(String, CGSize?, Bool)] = [
        ("unmeasured", nil, false), ("iPhone 17 portrait", size(402, 874), false), ("iPhone 17 landscape", size(874, 402), false),
        ("iPhone 17 Pro Max landscape", size(956, 440), false), ("Duo inner A portrait", size(669, 951), true),
        ("Duo inner A landscape", size(951, 669), true), ("Duo inner B portrait", size(626, 890), true),
        ("Duo outer portrait", size(466, 678), false), ("Duo outer landscape", size(678, 466), false),
        ("an iPad 13", size(1032, 1376), true), ("zero", .zero, false),
    ]
    for (name, s, isWideWindow) in sheets {
        for isPad in [true, false] {
            let expected = WindowClass.formSheetOnWide ? (isPad || isWideWindow) : isPad
            checkEqual(WindowClass.usesFormSheet(isPad: isPad, windowSize: s), expected,
                       "window: \(isPad ? "an iPad" : "a phone") in \(name) \(expected ? "uses" : "does not use") the form sheet")
        }
    }

    // capsOverview: every iPhone window today and every iPhone paper area 1.3 knows (the reference rows and 1.3's table of
    // measured devices) keeps the cap; the Duo's inner screen has none; unmeasured keeps it.
    var iPhoneAreas: [(String, CGSize)] = []
    for w in iPhoneWindows {
        iPhoneAreas.append(("window \(w)", w))
        iPhoneAreas.append(("window \(size(w.height, w.width))", size(w.height, w.width)))
    }
    for orientation in SpanOrientation.allCases {
        for kind in PageKind.allCases {
            iPhoneAreas.append(("reference \(orientation) \(kind)", SpanPlan.referenceViewport(kind, deviceClass: .iPhone, orientation: orientation)))
        }
    }
    iPhoneAreas += [
        ("iPhone 17 landscape week (measured)", size(750, 179)), ("iPhone 17 landscape day (measured)", size(750, 175)),
        ("iPhone Pro Max landscape week (estimate)", size(832, 217)), ("iPhone Pro Max landscape day (estimate)", size(832, 213)),
        ("iPhone 17 Pro Max portrait week (measured)", size(440, 622)), ("iPhone 17 Pro Max portrait day (measured)", size(440, 618)),
        ("iPhone portrait, band at its 35 % cap", size(402, 368)),
    ]
    for (name, s) in iPhoneAreas {
        checkEqual(WindowClass.capsOverview(windowSize: s), true, "window: the iPhone's \(name) keeps the overview cap")
    }
    for s in [size(669, 951), size(951, 669), size(626, 890), size(890, 626)] {
        checkEqual(WindowClass.capsOverview(windowSize: s), false, "window: the Duo's inner \(s) has no overview cap")
    }
    for s in [size(466, 678), size(678, 466)] {
        checkEqual(WindowClass.capsOverview(windowSize: s), true, "window: the Duo's outer \(s) keeps the overview cap")
    }
    for s in [nil, .zero, size(.nan, 669), size(-951, 669)] as [CGSize?] {
        checkEqual(WindowClass.capsOverview(windowSize: s), true, "window: an unmeasured \(s.map { "\($0)" } ?? "nil") keeps the overview cap")
    }

    // Opening: decided once, whether the size comes early or late, and never again (a fold or an unfold).
    var unfolded = WindowClass.Opening(stored: nil, isPad: false)
    checkEqual(unfolded.decided, nil, "opening: a phone with nothing stored is undecided at first")
    checkEqual(unfolded.windowSize(nil), nil, "opening: no size yet, still undecided")
    checkEqual(unfolded.windowSize(.zero), nil, "opening: a zero size, still undecided")
    checkEqual(unfolded.decided, nil, "opening: still undecided after unmeasured sizes")
    checkEqual(unfolded.windowSize(size(669, 951)), .month, "opening: the inner screen decides the month")
    checkEqual(unfolded.decided, .month, "opening: decided the month")
    checkEqual(unfolded.windowSize(size(466, 678)), .month, "opening: folded 669 → 466 afterwards, still the month")
    checkEqual(unfolded.windowSize(size(678, 466)), .month, "opening: the outer screen turned, still the month")
    checkEqual(unfolded.windowSize(nil), .month, "opening: an unmeasured size afterwards, still the month")
    checkEqual(unfolded.decided, .month, "opening: the month for good")

    var folded = WindowClass.Opening(stored: nil, isPad: false)
    checkEqual(folded.windowSize(size(466, 678)), .week, "opening: the outer screen decides the week")
    checkEqual(folded.windowSize(size(669, 951)), .week, "opening: unfolded 466 → 669 afterwards, still the week")
    checkEqual(folded.windowSize(size(951, 669)), .week, "opening: the inner screen turned, still the week")
    checkEqual(folded.decided, .week, "opening: the week for good")

    var turned = WindowClass.Opening(stored: nil, isPad: false)
    checkEqual(turned.windowSize(size(874, 402)), .week, "opening: an iPhone on its side the first time opens the week")
    checkEqual(turned.windowSize(size(402, 874)), .week, "opening: turned upright afterwards, still the week")

    // The size early (straight away) or late (after unmeasured ones): the same answer and the same state.
    var early = WindowClass.Opening(stored: nil, isPad: false)
    var late = WindowClass.Opening(stored: nil, isPad: false)
    _ = early.windowSize(size(951, 669))
    for s in [nil, .zero, size(0, 669), size(951, .nan)] as [CGSize?] { _ = late.windowSize(s) }
    _ = late.windowSize(size(951, 669))
    checkEqual(early.decided, .month, "opening: the size first decides the month")
    checkEqual(late.decided, .month, "opening: the size late decides the month too")
    checkEqual(early, late, "opening: early and late end in the same state")

    let stored = WindowClass.Opening(stored: .day, isPad: false)
    checkEqual(stored.decided, .day, "opening: a stored kind is decided from the start")
    var storedThen = stored
    checkEqual(storedThen.windowSize(size(669, 951)), .day, "opening: a stored kind stays, whatever the size")
    checkEqual(storedThen.windowSize(size(466, 678)), .day, "opening: a stored kind stays through a fold")
    checkEqual(WindowClass.Opening(stored: .year, isPad: true).decided, .year, "opening: a stored kind wins on an iPad too")

    var pad = WindowClass.Opening(stored: nil, isPad: true)
    checkEqual(pad.decided, .month, "opening: an iPad is decided (the month) from the start")
    checkEqual(pad.windowSize(size(402, 874)), .month, "opening: an iPad keeps the month in a narrow window")
    checkEqual(pad.windowSize(nil), .month, "opening: an iPad keeps the month unmeasured")
}

// MARK: - FingerDefault (§4.8)

private typealias Finger = FingerDefault
private typealias Act = FingerDefault.Action

/// A Pencil stroke: down, then up. The action of the down (always nil: nothing while a touch is down) and of the up.
private func pencilStroke(_ f: inout Finger) -> (down: Act?, up: Act?) {
    let down = f.touchDown(pencil: true)
    let up = f.touchUp()
    return (down, up)
}

/// A finger's tap: down, then up.
private func fingerTap(_ f: inout Finger) -> (down: Act?, up: Act?) {
    let down = f.touchDown(pencil: false)
    let up = f.touchUp()
    return (down, up)
}

private func name(_ a: Act?) -> String {
    guard let a else { return "nothing" }
    switch a {
    case .turnOff(let rearm): return "turnOff(rearmGuide: \(rearm))"
    case .turnOnAgain: return "turnOnAgain"
    case .rebind: return "rebind"
    }
}

private func fingerDefaultChecks() {
    checkEqual(Finger.Signal.allCases, [.hinge, .pencil], "finger: the signals are the hinge and the Pencil only (no window)")

    // origin(mark:device:)
    let origins: [(String?, String?, Finger.Origin)] = [
        ("person", "D-1", .person), ("person", nil, .person), ("person", "", .person),
        ("D-1", "D-1", .app), (nil, "D-1", .carried), ("", "D-1", .carried), ("D-2", "D-1", .moved), ("PERSON", "D-1", .moved),
        ("D-1", nil, .carried), (nil, nil, .carried), ("", nil, .carried), ("D-2", nil, .carried), ("D-1", "", .carried),
    ]
    for (mark, device, expected) in origins {
        checkEqual(Finger.origin(mark: mark, device: device), expected,
                   "finger: the mark \(mark.map { "\"\($0)\"" } ?? "nil") on the device \(device.map { "\"\($0)\"" } ?? "nil") is \(expected)")
    }

    // The table of §4.8, row by row (a phone; H = a hinge present, P = a Pencil stroke, both after `appeared`).
    let table: [(Finger.Origin, Bool, Finger.Signal, Act?)] = [
        (.app, true, .hinge, .turnOff(rearmGuide: true)), (.app, true, .pencil, .turnOff(rearmGuide: true)),
        (.app, false, .hinge, nil), (.app, false, .pencil, nil),
        (.carried, true, .hinge, nil), (.carried, true, .pencil, .turnOff(rearmGuide: false)),
        (.carried, false, .hinge, nil), (.carried, false, .pencil, nil),
        (.moved, true, .hinge, nil), (.moved, true, .pencil, .turnOff(rearmGuide: false)),
        (.moved, false, .hinge, .rebind), (.moved, false, .pencil, .rebind),
        (.person, true, .hinge, nil), (.person, true, .pencil, nil),
        (.person, false, .hinge, nil), (.person, false, .pencil, nil),
    ]
    for isPad in [false, true] {
        for (origin, on, signal, phoneAction) in table {
            let label = "finger: \(isPad ? "an iPad" : "a phone"), \(origin), \(on ? "on" : "off"), \(signal)"
            let expected = isPad ? nil : phoneAction
            var f = Finger(isPad: isPad)
            checkEqual(f.appeared(allowFinger: on, origin: origin), nil, "\(label): nothing at appeared")
            // Not a switch over Signal: a third signal (M-f7) must still build, and fail the allCases row above.
            let got: Act?
            if signal == .hinge {
                got = f.hinge(true)
            } else {
                let stroke = pencilStroke(&f)
                checkEqual(stroke.down, nil, "\(label): nothing while the Pencil is down")
                got = stroke.up
            }
            checkEqual(got, expected, "\(label) → \(name(expected))")
            if expected != nil {
                // Once only: neither signal does anything after it.
                checkEqual(f.hinge(true), nil, "\(label): a second hinge does nothing")
                checkEqual(pencilStroke(&f).up, nil, "\(label): a second Pencil stroke does nothing")
                checkEqual(f.hinge(false), nil, "\(label): a hinge's false does nothing")
            }
        }
    }

    // rearmGuide: true for the app's own value only.
    do {
        var app = Finger(isPad: false)
        _ = app.appeared(allowFinger: true, origin: .app)
        checkEqual(pencilStroke(&app).up, .turnOff(rearmGuide: true), "finger: the app's value turned off by P shows the guide card again")
        var carried = Finger(isPad: false)
        _ = carried.appeared(allowFinger: true, origin: .carried)
        checkEqual(pencilStroke(&carried).up, .turnOff(rearmGuide: false), "finger: a value carried from 1.3 turned off by P shows no card")
        var moved = Finger(isPad: false)
        _ = moved.appeared(allowFinger: true, origin: .moved)
        checkEqual(pencilStroke(&moved).up, .turnOff(rearmGuide: false), "finger: a moved value turned off by P shows no card")
        var hinged = Finger(isPad: false)
        _ = hinged.appeared(allowFinger: true, origin: .app)
        checkEqual(hinged.hinge(true), .turnOff(rearmGuide: true), "finger: the app's value turned off by H shows the guide card again")
    }

    // The rollback (戻し): moved and off.
    do {
        var f = Finger(isPad: false)
        checkEqual(f.appeared(allowFinger: false, origin: .moved), nil, "rollback: moved and off waits for the hinge at appeared")
        checkEqual(fingerTap(&f).up, nil, "rollback: a finger's tap does not decide it")
        checkEqual(f.touchesReset(), nil, "rollback: a reset does not decide it")
        checkEqual(f.hinge(true), .rebind, "rollback: a hinge keeps it off and takes it over (rebind)")
        checkEqual(f.hinge(false), nil, "rollback: a later false does nothing")
        checkEqual(pencilStroke(&f).up, nil, "rollback: a Pencil afterwards does nothing (off already)")
        checkEqual(f.hinge(true), nil, "rollback: once only")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .moved)
        checkEqual(f.hinge(false), .turnOnAgain, "rollback: no hinge turns it on again (turnOnAgain)")
        checkEqual(f.hinge(false), nil, "rollback: a second false does nothing")
        checkEqual(fingerTap(&f).up, nil, "rollback: a finger afterwards does nothing")
        // From now on the app's row: a Pencil turns it off again, with the guide card.
        checkEqual(pencilStroke(&f).up, .turnOff(rearmGuide: true), "rollback: afterwards P turns it off as the app's value")
        checkEqual(pencilStroke(&f).up, nil, "rollback: and only once")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .moved)
        checkEqual(f.hinge(false), .turnOnAgain, "rollback: turned on again")
        checkEqual(f.hinge(true), .turnOff(rearmGuide: true), "rollback: a hinge that answers late turns it off as the app's value")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .moved)
        checkEqual(f.touchDown(pencil: false), nil, "rollback: a finger down")
        checkEqual(f.hinge(false), nil, "rollback: no hinge while a finger is down: it waits")
        checkEqual(f.touchUp(), .turnOnAgain, "rollback: turned on again once the finger lifts")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .moved)
        let stroke = pencilStroke(&f)
        checkEqual(stroke.down, nil, "rollback: nothing while the Pencil is down")
        checkEqual(stroke.up, .rebind, "rollback: a Pencil shows a Pencil device: kept off (rebind) before the hinge answers")
        checkEqual(f.hinge(false), nil, "rollback: a later false does not turn it on")
    }
    for present in [true, false] {
        var moved = Finger(isPad: false)
        _ = moved.appeared(allowFinger: true, origin: .moved)
        checkEqual(moved.hinge(present), nil, "rollback: moved and on, a hinge's \(present) does nothing")
        var person = Finger(isPad: false)
        _ = person.appeared(allowFinger: false, origin: .person)
        checkEqual(person.hinge(present), nil, "rollback: the person's off is never rolled back (hinge \(present))")
        var carried = Finger(isPad: false)
        _ = carried.appeared(allowFinger: false, origin: .carried)
        checkEqual(carried.hinge(present), nil, "rollback: a carried off is not rolled back (hinge \(present))")
        var app = Finger(isPad: false)
        _ = app.appeared(allowFinger: false, origin: .app)
        checkEqual(app.hinge(present), nil, "rollback: the app's own off is not rolled back (hinge \(present))")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .person)
        checkEqual(pencilStroke(&f).up, nil, "rollback: the person's off, a Pencil does nothing")
    }

    // The order (C2): nothing before appeared; what came first is acted on once after it.
    do {
        var f = Finger(isPad: false)
        checkEqual(f.hinge(true), nil, "order: a hinge before appeared does nothing")
        checkEqual(pencilStroke(&f).up, nil, "order: a Pencil before appeared does nothing")
        checkEqual(f.touchesReset(), nil, "order: a reset before appeared does nothing")
        checkEqual(f.appeared(allowFinger: true, origin: .app), .turnOff(rearmGuide: true), "order: acted on once at appeared")
        checkEqual(f.hinge(true), nil, "order: nothing after it")
        checkEqual(pencilStroke(&f).up, nil, "order: nothing after it (Pencil)")
    }
    do {
        var f = Finger(isPad: false)
        checkEqual(pencilStroke(&f).up, nil, "order: a Pencil before appeared (carried)")
        checkEqual(f.appeared(allowFinger: true, origin: .carried), .turnOff(rearmGuide: false), "order: a carried value turned off at appeared")
    }
    do {
        var f = Finger(isPad: false)
        checkEqual(f.hinge(true), nil, "order: a hinge before appeared (carried)")
        checkEqual(f.appeared(allowFinger: true, origin: .carried), nil, "order: a carried value ignores the hinge at appeared")
    }
    do {
        var f = Finger(isPad: false)
        checkEqual(f.hinge(false), nil, "order: no hinge before appeared (moved, off)")
        checkEqual(f.appeared(allowFinger: false, origin: .moved), .turnOnAgain, "order: rolled back at appeared")
    }
    do {
        var f = Finger(isPad: false)
        checkEqual(f.touchDown(pencil: true), nil, "order: a Pencil down before appeared")
        checkEqual(f.appeared(allowFinger: true, origin: .app), nil, "order: appeared while the Pencil is down does nothing")
        checkEqual(f.touchUp(), .turnOff(rearmGuide: true), "order: acted on when the Pencil lifts")
    }
    do {
        // A second appeared changes nothing (the state the actions keep stays).
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .app)
        checkEqual(f.hinge(true), .turnOff(rearmGuide: true), "order: turned off")
        checkEqual(f.appeared(allowFinger: true, origin: .app), nil, "order: a second appeared does nothing")
        checkEqual(pencilStroke(&f).up, nil, "order: and does not undo the off")
        var g = Finger(isPad: false)
        _ = g.appeared(allowFinger: true, origin: .carried)
        checkEqual(g.appeared(allowFinger: true, origin: .app), nil, "order: a second appeared with another origin")
        checkEqual(g.hinge(true), nil, "order: the first origin (carried) stays")
    }
    do {
        // Without appeared nothing ever happens, whatever comes.
        var f = Finger(isPad: false)
        var any: [Act?] = [f.hinge(true), f.hinge(false)]
        for _ in 0..<3 { let s = pencilStroke(&f); any += [s.down, s.up] }
        any += [f.touchDown(pencil: false), f.touchesReset()]
        checkEqual(any.compactMap { $0 }.count, 0, "order: nothing at all before appeared")
    }

    // While touching (C6): nothing while any touch is down, once when all have lifted; a reset counts as lifted.
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .app)
        checkEqual(f.touchDown(pencil: false), nil, "touches: a finger down")
        checkEqual(f.hinge(true), nil, "touches: a hinge while a finger is down waits")
        checkEqual(f.touchUp(), .turnOff(rearmGuide: true), "touches: done when the finger lifts")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .carried)
        checkEqual(f.touchDown(pencil: true), nil, "touches: a Pencil down")
        checkEqual(f.hinge(false), nil, "touches: a hinge's false while the Pencil is down")
        checkEqual(f.touchUp(), .turnOff(rearmGuide: false), "touches: done when the Pencil lifts")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .carried)
        checkEqual(f.touchDown(pencil: true), nil, "touches: a Pencil down (two touches)")
        checkEqual(f.touchDown(pencil: false), nil, "touches: and a finger (the palm)")
        checkEqual(f.touchUp(), nil, "touches: the Pencil lifts, the finger is still down: nothing")
        checkEqual(f.touchDown(pencil: false), nil, "touches: a second finger")
        checkEqual(f.touchUp(), nil, "touches: one finger lifts, one is still down: nothing")
        checkEqual(f.touchUp(), .turnOff(rearmGuide: false), "touches: all lifted: done once")
        checkEqual(f.touchUp(), nil, "touches: an extra lift does nothing")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .app)
        checkEqual(f.touchDown(pencil: true), nil, "touches: a Pencil down (reset)")
        checkEqual(f.touchDown(pencil: false), nil, "touches: a finger down (reset)")
        checkEqual(f.touchesReset(), .turnOff(rearmGuide: true), "touches: the watcher's reset counts as all lifted")
        checkEqual(f.touchesReset(), nil, "touches: a second reset does nothing")
    }
    do {
        // Lifts without downs never count below zero.
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .carried)
        checkEqual(f.touchUp(), nil, "touches: a lift with nothing down")
        checkEqual(f.touchUp(), nil, "touches: another lift with nothing down")
        checkEqual(f.touchDown(pencil: true), nil, "touches: then a Pencil down")
        checkEqual(f.touchUp(), .turnOff(rearmGuide: false), "touches: and up: done (the count never went below zero)")
    }
    do {
        // A finger alone (or a pointer) is never P.
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .carried)
        for _ in 0..<5 { checkEqual(fingerTap(&f).up, nil, "touches: a finger or a pointer alone never turns it off") }
        checkEqual(f.hinge(false), nil, "touches: nor a hinge's false")
    }
    do {
        // An ordinary iPhone on 1.4's first launch (the app's value, on): no hinge, fingers and pointers only → never off.
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .app)
        checkEqual(fingerTap(&f).up, nil, "touches: the app's on, a finger before the hinge answers does nothing (an ordinary iPhone)")
        checkEqual(f.hinge(false), nil, "touches: the app's on, the hinge's false does nothing (an ordinary iPhone)")
        for _ in 0..<3 { checkEqual(fingerTap(&f).up, nil, "touches: the app's on, a finger or a pointer does nothing (an ordinary iPhone)") }
        checkEqual(f.touchesReset(), nil, "touches: the app's on, a reset does nothing (an ordinary iPhone)")
    }

    // The person: after the switch nothing ever happens.
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .app)
        f.personSwitched()
        checkEqual(f.hinge(true), nil, "person: after the switch a hinge does nothing")
        checkEqual(pencilStroke(&f).up, nil, "person: after the switch a Pencil does nothing")
        checkEqual(f.touchesReset(), nil, "person: after the switch a reset does nothing")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: true, origin: .carried)
        checkEqual(f.touchDown(pencil: true), nil, "person: a Pencil down")
        f.personSwitched()
        checkEqual(f.touchUp(), nil, "person: switched while the Pencil was down: nothing when it lifts")
    }
    do {
        var f = Finger(isPad: false)
        _ = f.appeared(allowFinger: false, origin: .moved)
        f.personSwitched()
        checkEqual(f.hinge(false), nil, "person: switched before the rollback: no rollback")
    }
    do {
        var f = Finger(isPad: false)
        f.personSwitched()
        checkEqual(f.hinge(true), nil, "person: switched before appeared")
        checkEqual(f.appeared(allowFinger: true, origin: .app), nil, "person: switched before appeared: nothing at appeared")
        checkEqual(pencilStroke(&f).up, nil, "person: nor after it")
    }

    // An iPad: nothing, whatever comes.
    do {
        var any: [Act?] = []
        for origin in [Finger.Origin.app, .carried, .moved, .person] {
            for on in [true, false] {
                var f = Finger(isPad: true)
                any.append(f.hinge(false))
                any.append(f.appeared(allowFinger: on, origin: origin))
                any.append(f.hinge(true))
                let s = pencilStroke(&f)
                any += [s.down, s.up, f.touchDown(pencil: false), f.touchesReset()]
            }
        }
        checkEqual(any.count, 56, "iPad: every input was given")
        checkEqual(any.compactMap { $0 }.count, 0, "iPad: FingerDefault(isPad: true) never acts")
    }

    // The same inputs give the same state (a value type, Equatable).
    func fed() -> Finger {
        var x = Finger(isPad: false)
        _ = x.hinge(false)
        _ = x.appeared(allowFinger: true, origin: .carried)
        _ = x.touchDown(pencil: false)
        return x
    }
    checkEqual(fed(), fed(), "finger: the same inputs, the same state")
    checkEqual(fed() == Finger(isPad: false), false, "finger: inputs change the state")
}
