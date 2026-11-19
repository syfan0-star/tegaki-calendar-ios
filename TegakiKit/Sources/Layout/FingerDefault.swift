import Foundation

/// 1.4 (docs/M7D_CONTRACT.md §2.1, §4.8; the owner's decision of 11/20 「Duoでもペンシルを使うので、その前提で作って下さい。」): whether
/// the app changes 「指でも書く」 (allowFinger) on a phone, so that the iPhone Duo works as an iPad does (the Pencil writes, a finger
/// moves the paper). A pure state: it reads no UIKit, no UserDefaults and no window size; the app's glue (`PencilPhone`) feeds it
/// the calls below and writes the `Action`s it returns.
///
/// The signals are things of the device itself: P, a touch of `UITouch.TouchType.pencil` anywhere in the window (only the Duo
/// takes an Apple Pencil among the iPhones), and H, a hinge `UIHingeInteraction` reports. Never the window's width (F1: iPhone
/// Mirroring widens an ordinary iPhone's window too).
///
/// Who wrote today's value decides what a signal does (the table of §4.8; only while allowFinger is on):
///
///     who wrote it                       | H (a hinge)              | P (a Pencil touched)
///     the app on this device (.app)      | off, the guide card again | off, the guide card again
///     carried over from 1.3 (.carried)   | nothing                  | off, no card
///     moved from another device (.moved) | nothing                  | off, no card
///     the person (.person)               | nothing                  | nothing
///
/// The rollback (戻し): a value the app turned off on another device and that came here with a backup or a move (.moved and off)
/// is kept off (`rebind`) on a device with a hinge, and turned on again once (`turnOnAgain`) on one without it (no hinge, the
/// hinge not used, before iOS 27.1, no answer in 2 seconds), so a phone without a Pencil never keeps a Duo's off. A Pencil touch
/// shows this device takes a Pencil, so it keeps the value off too (`rebind`). Until the hinge has answered (and no Pencil
/// touched) it waits.
///
/// When: nothing before `appeared` (C2: a hinge or a touch that comes first is remembered and acted on once after it), never
/// while any touch is down (C6: Pencil, finger and pointer alike; a line is never cut by a change of the drawing policy), at
/// most one action per call, never after the person switched, and never on an iPad (`isPad`: an iPad keeps 1.3's default off
/// and nothing is attached there). After an action the value is the app's on this device (`.app`).
public struct FingerDefault: Equatable, Sendable {
    /// Who wrote today's value of 「指でも書く」 (from the mark allowFingerDrawingAuto).
    public enum Origin: Equatable, Sendable { case app, carried, moved, person }

    /// The signals. The window's size is not one of them (F1).
    public enum Signal: Equatable, Sendable, CaseIterable { case hinge, pencil }

    /// What the app does (`PencilPhone.apply` writes it to UserDefaults and AppSettings).
    public enum Action: Equatable, Sendable {
        /// allowFinger = false, the mark = this device; with `rearmGuide` the records of the week's and the day's guide cards
        /// are cleared (only for `.app`).
        case turnOff(rearmGuide: Bool)
        /// allowFinger = true, the mark = this device (a value the app turned off on another device, on a device without a
        /// Pencil, once).
        case turnOnAgain
        /// The mark = this device, the value kept (an off from another device, taken over by a device with a hinge).
        case rebind
    }

    /// The mark's meaning: "person" → `.person`; the same as `device` → `.app`; missing or empty → `.carried`; anything else →
    /// `.moved`. A `device` of nil (this device's mark cannot be read yet: before the first unlock after a restart) or empty
    /// reads everything but "person" as `.carried` (this launch goes by P alone: the safe side).
    public static func origin(mark: String?, device: String?) -> Origin {
        if mark == "person" { return .person }
        guard let device, !device.isEmpty else { return .carried }
        guard let mark, !mark.isEmpty else { return .carried }
        return mark == device ? .app : .moved
    }

    private let isPad: Bool
    /// `appeared` has come (C2).
    private var hasAppeared = false
    /// Today's value and who wrote it (read at `appeared`, then kept up to date by the actions).
    private var allowFinger = true
    private var origin = Origin.carried
    /// The person touched the switch: nothing ever again.
    private var personChose = false
    /// The signals seen: `.hinge` once a hinge was there (it stays after a later false), `.pencil` once a Pencil touched.
    private var seen: Set<Signal> = []
    /// The hinge watcher has answered (true or false).
    private var hingeAnswered = false
    /// The touches down in the window now (Pencil, finger, pointer).
    private var touchesDown = 0

    public init(isPad: Bool) {
        self.isPad = isPad
    }

    /// Once, after `appear()` wrote 1.3's default (the origin read after that write, C2). A second call changes nothing.
    public mutating func appeared(allowFinger: Bool, origin: Origin) -> Action? {
        guard !hasAppeared else { return nil }
        hasAppeared = true
        self.allowFinger = allowFinger
        self.origin = personChose ? .person : origin
        return decide()
    }

    /// The hinge watcher's answer: true, a hinge is there; false, none, no API, not used or no answer in 2 seconds. Any number of
    /// times; a false after a true keeps the true.
    public mutating func hinge(_ present: Bool) -> Action? {
        hingeAnswered = true
        if present { seen.insert(.hinge) }
        return decide()
    }

    /// A touch went down anywhere in the window, on the paper or a button (a Pencil or not): one more down; a Pencil is P.
    public mutating func touchDown(pencil: Bool) -> Action? {
        touchesDown += 1
        if pencil { seen.insert(.pencil) }
        return decide()
    }

    /// A touch ended or was cancelled: one fewer down. When none is left, what waited is done.
    public mutating func touchUp() -> Action? {
        touchesDown = max(0, touchesDown - 1)
        return decide()
    }

    /// The watcher's reset: every touch left counts as lifted.
    public mutating func touchesReset() -> Action? {
        touchesDown = 0
        return decide()
    }

    /// The person touched the switch (the origin is `.person` now): nothing ever again.
    public mutating func personSwitched() {
        personChose = true
        origin = .person
    }

    /// The action due now, if any, with the state updated to it (the value is the app's afterwards).
    private mutating func decide() -> Action? {
        guard !isPad, hasAppeared, !personChose, touchesDown == 0 else { return nil }
        let hinged = seen.contains(.hinge)
        let pencil = seen.contains(.pencil)
        let action: Action?
        switch origin {
        case .person:
            action = nil
        case .app:
            action = allowFinger && (hinged || pencil) ? .turnOff(rearmGuide: true) : nil
        case .carried:
            action = allowFinger && pencil ? .turnOff(rearmGuide: false) : nil
        case .moved:
            if allowFinger {
                action = pencil ? .turnOff(rearmGuide: false) : nil
            } else if hinged || pencil {
                action = .rebind
            } else if hingeAnswered {
                action = .turnOnAgain
            } else {
                action = nil
            }
        }
        guard let action else { return nil }
        switch action {
        case .turnOff: allowFinger = false
        case .turnOnAgain: allowFinger = true
        case .rebind: break
        }
        origin = .app
        return action
    }
}
