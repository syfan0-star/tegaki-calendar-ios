import Layout
import SwiftUI
import UIKit

/// 1.4 (docs/M7D_CONTRACT.md §2.1, §4.8, 0d-36 … 0d-42; the owner's decision of 11/20 「Duoでもペンシルを使うので、その前提で
/// 作って下さい。」): the app's glue of `FingerDefault`, so the iPhone Duo works as an iPad does — the Apple Pencil writes, a
/// finger moves the paper, 「指でも書く」 off. The decision is the Kit's pure state (`FingerDefault`); this class only feeds it
/// and writes what it answers:
/// - the device's mark (`deviceMark`, `identifierForVendor`) and the mark key `allowFingerDrawingAuto` that says who wrote
///   today's 「指でも書く」 (`origin`; the person's switch writes "person", `personSet`);
/// - the first launch's default, 1.3's lines with the mark (`launchDefault`, `CalendarRootScreen.appear`);
/// - P, the Pencil's touch: a new instance of the frozen `InkTouchObserver` on the UIWindow (`attach`), which counts every
///   touch of the window — the Pencil, a finger, a pointer, on the paper, the bars or a sheet — and recognises nothing;
/// - H, the hinge: `UIHingeInteraction` on the window's root view, only when `usesHinge` (§4.2), on iOS 27.1 and later and
///   not on Mac Catalyst (Xcode 27.2's known issue 185924957, §3.8); otherwise the answer is "no hinge" at once, and it is
///   "no hinge" too when the first update does not come within `hingeWait` (the wait is injectable, `sleep`). Never used for
///   the layout (Apple's note on the hinge, §4.10);
/// - `apply`: the actions written to UserDefaults (the value and the mark) and `AppSettings` (the guide records), in
///   screenshot mode too; one that a touch's lift decided waits for the main actor's next turn, so a Pencil tap on the
///   person's own switch stays theirs (`afterTheLift`).
/// Nothing reads the window's size or the kind of device: an iPad (and a Mac running the iPad app) attaches nothing and its
/// `FingerDefault` answers nothing, so an iPad and an ordinary iPhone (no Pencil, no hinge) keep 1.3's 「指でも書く」.
@MainActor
final class PencilPhone {
    /// `String`: "person", or the mark of the device on which the app wrote today's value (`AppSettings.allowFingerAutoKey`).
    /// In `UserDefaults.standard` only: never sent to iCloud (a backup or a move to a new iPhone may carry it, §4.8).
    nonisolated static let markKey = AppSettings.allowFingerAutoKey
    /// The mark of the person's own switch (the toolbar's or the settings').
    nonisolated static let personMark = "person"
    /// Whether the hinge (H) is watched at all. Decided on D1 by the measurements of the CI's `duo-shots` (docs/M7D_CONTRACT.md
    /// §4.2: true only when an iPhone Duo screen of the simulator reports a hinge that is not nil and the iPhone 17 reports
    /// nil). Until then false: no H, the Pencil's touch (P) alone turns 「指でも書く」 off on a Duo.
    nonisolated static let usesHinge = false
    /// How long the first hinge update may take before the answer is "no hinge" (§2.1, §4.8).
    nonisolated static let hingeWait: TimeInterval = 2

    /// This device's mark: `identifierForVendor` (another value on another device; nil after a restart before the first
    /// unlock). Only compared with the stored mark on this device, never sent anywhere (App Privacy's "no data collected"
    /// stays true).
    static func deviceMark() -> String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    /// Who wrote today's value (`FingerDefault.origin` of the stored mark and this device's).
    static func origin(_ defaults: UserDefaults, device: String?) -> FingerDefault.Origin {
        FingerDefault.origin(mark: defaults.string(forKey: markKey), device: device)
    }

    /// The person's switch (the toolbar's and the settings' Binding, `CalendarRootScreen`): the value, and the mark "person".
    static func personSet(_ value: Bool, defaults: UserDefaults) {
        defaults.set(value, forKey: AppSettings.allowFingerKey)
        defaults.set(personMark, forKey: markKey)
    }

    /// `CalendarRootScreen.appear`'s default (1.3's lines, the same moment and values: once, while
    /// `allowFingerDrawingChosen` is not on record, `allowFingerDrawingChosen` = true and 「指でも書く」 = !isPad), with this
    /// phone's mark written beside it on that first launch only (nil: no mark, `.carried`; an iPad: no mark, `.carried`).
    /// The value and who wrote it, for `FingerDefault.appeared`: on the launch that wrote the default the origin is what was
    /// written (`.app` with a mark), not read back, so the UI tests' and the photos' launch arguments
    /// `-allowFingerDrawingChosen NO -allowFingerDrawingAuto ""` (which keep shadowing the two keys afterwards) make a first
    /// launch (§2.1). Any other launch reads both, unchanged (an update from 1.3 has no mark: `.carried`).
    static func launchDefault(_ defaults: UserDefaults, isPad: Bool, device: String?) -> (allowFinger: Bool, origin: FingerDefault.Origin) {
        guard !defaults.bool(forKey: AppSettings.allowFingerChosenKey) else {
            return (defaults.bool(forKey: AppSettings.allowFingerKey), origin(defaults, device: device))
        }
        // Pencil only on iPad by default (DESIGN §2.1, §2.11); on an iPhone Duo the Pencil's touch or the hinge turns it off
        // afterwards (FingerDefault, §4.8).
        let allowFinger = !isPad
        defaults.set(true, forKey: AppSettings.allowFingerChosenKey)
        defaults.set(allowFinger, forKey: AppSettings.allowFingerKey)
        // §4.8 (iPad では何もしない; the rollback only for a value the app turned off on a Duo): an iPad writes no mark. Its
        // `FingerDefault` never acts, and its off read as `.carried` on a phone it is restored to stays off there, as in 1.3
        // (with the iPad's mark it would read `.moved` and off, and be turned on again).
        guard !isPad, let device, !device.isEmpty else { return (allowFinger, .carried) }
        defaults.set(device, forKey: markKey)
        return (allowFinger, .app)
    }

    /// What was fed to the state, in order (the tests read it through `onInput`).
    enum Input: Equatable {
        case appeared(allowFinger: Bool, origin: FingerDefault.Origin)
        case hinge(Bool)
        case touchDown(pencil: Bool)
        case touchUp
        case touchesReset
        case person
    }

    /// An iPad (`FingerDefault(isPad:)` answers nothing, `attach` attaches nothing).
    let isPad: Bool
    /// The decision (§4.8's table).
    private(set) var state: FingerDefault
    /// Who wrote today's value as the decision sees it (§4.8): the launch's (`appeared`), the app's on this device after an
    /// action, the person's after the switch. For screenshot mode's `duo measure:` line (`origin=`, §2.1): on a launch whose
    /// arguments shadow the mark it is still the launch's, not the shadow's.
    private(set) var origin: FingerDefault.Origin = .carried
    /// Tests: every input, as it is fed (nil in the app).
    var onInput: ((Input) -> Void)?
    /// Tests: every action, once written (nil in the app).
    var onApply: ((FingerDefault.Action) -> Void)?

    private let defaults: UserDefaults
    private let device: @MainActor () -> String?
    private let watchesHinge: Bool
    private let sleep: @MainActor (TimeInterval) async -> Void
    private let simultaneous = Simultaneous()
    private weak var window: UIWindow?
    private var observer: InkTouchObserver?
    private weak var hingeView: UIView?
    private var hingeInteraction: UIInteraction?
    private var hingeHeard = false
    private var hingeWaitTask: Task<Void, Never>?
    private var appearedFed = false

    /// `defaults`: where the value and the mark are (the screen's `@AppStorage` store); the guide records are `AppSettings`'.
    /// `deviceMark`, `usesHinge` and `sleep` are the app's by default (the tests pass their own).
    init(isPad: Bool, defaults: UserDefaults = .standard, deviceMark: @escaping @MainActor () -> String? = PencilPhone.deviceMark,
         usesHinge: Bool = PencilPhone.usesHinge,
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) {
        self.isPad = isPad
        state = FingerDefault(isPad: isPad)
        self.defaults = defaults
        device = deviceMark
        watchesHinge = usesHinge
        self.sleep = sleep
    }

    /// The UIWindow's watchers, once the screen knows its window (its first layout; again only for another window). On an
    /// iPad nothing. A new `InkTouchObserver` (the frozen recogniser, used as it is) on the window: each touch's down and up
    /// go to `FingerDefault.touchDown(pencil:)` and `touchUp`; it recognises with every other recogniser (`Simultaneous`).
    /// Then the hinge: `UIHingeInteraction` on the window's root view when `usesHinge`, on iOS 27.1 and later, not on Mac
    /// Catalyst — its updates' `hinge != nil` go to `FingerDefault.hinge` —, else "no hinge" at once.
    func attach(to window: UIWindow, isPad: Bool) {
        guard !isPad, window !== self.window else { return }
        detach()
        self.window = window
        let observer = InkTouchObserver(target: nil, action: nil)
        observer.delegate = simultaneous
        observer.onChange = { [weak self] change in self?.touched(change) }
        window.addGestureRecognizer(observer)
        self.observer = observer
        watchHinge(on: window.rootViewController?.view ?? window)
    }

    /// The watchers off the window they were on (a move to another window): what was still down counts as lifted.
    private func detach() {
        if let observer {
            observer.view?.removeGestureRecognizer(observer)
            self.observer = nil
            feed(.touchesReset) { $0.touchesReset() }
        }
        if let hingeInteraction {
            hingeView?.removeInteraction(hingeInteraction)
            self.hingeInteraction = nil
        }
        hingeWaitTask?.cancel()
        hingeWaitTask = nil
    }

    /// The window's watcher: a touch went down (the Pencil is P) or lifted.
    func touched(_ change: InkTouchObserver.Change) {
        switch change {
        case .down(let type):
            let pencil = type == .pencil
            feed(.touchDown(pencil: pencil)) { $0.touchDown(pencil: pencil) }
        case .up:
            feed(.touchUp) { $0.touchUp() }
        }
    }

    /// H (§4.8): only when `usesHinge`; never for the layout.
    private func watchHinge(on view: UIView) {
        #if !targetEnvironment(macCatalyst)
        if watchesHinge, #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak self] _, update in
                self?.hingeAnswered(update.hinge != nil)
            }
            view.addInteraction(interaction)
            hingeView = view
            hingeInteraction = interaction
            waitForFirstHingeUpdate()
            return
        }
        #endif
        hingeAnswered(false)
    }

    /// The first hinge update did not come within `hingeWait`: "no hinge" (a later update still counts). No update at all
    /// and an update whose `hinge` is nil are the same answer (`hingeAnswered(false)`): on the unit tests' simulator (an
    /// iPad, iOS 27.2) an interaction on a window's root view got no update in 5 s (CI run 44649291195), so where a device
    /// sends none it is this wait that answers. Only the wait's full time is silence: a wait cancelled (another wait
    /// started, or the watchers moved to another window, whose own wait starts then) answers nothing, though the real sleep
    /// returns at once then.
    func waitForFirstHingeUpdate() {
        hingeWaitTask?.cancel()
        hingeWaitTask = Task { @MainActor [weak self, sleep] in
            await sleep(Self.hingeWait)
            guard !Task.isCancelled, let self, !self.hingeHeard else { return }
            self.hingeAnswered(false)
        }
    }

    /// The hinge watcher's answer (any number of times; a hinge seen once stays seen, `FingerDefault.hinge`).
    func hingeAnswered(_ present: Bool) {
        hingeHeard = true
        feed(.hinge(present)) { $0.hinge(present) }
    }

    /// After `appear()` wrote 1.3's default (`launchDefault`'s answer), once (C2: a hinge or a touch before it waits for it).
    func appeared(allowFinger: Bool, origin: FingerDefault.Origin) {
        if !appearedFed, self.origin != .person {
            self.origin = origin
        }
        appearedFed = true
        feed(.appeared(allowFinger: allowFinger, origin: origin)) { $0.appeared(allowFinger: allowFinger, origin: origin) }
    }

    /// The person switched 「指でも書く」 (after `personSet`): the app never changes it again.
    func personSwitched() {
        onInput?(.person)
        origin = .person
        state.personSwitched()
    }

    /// Writes an action (in screenshot mode too). `turnOff`: 「指でも書く」 off, the mark this device's, and with `rearmGuide`
    /// the week's and the day's guide records forgotten (the guide shows once more with the one-finger words, F10).
    /// `turnOnAgain`: 「指でも書く」 on, the mark this device's. `rebind`: the mark this device's. No mark is written while
    /// this device's cannot be read.
    func apply(_ action: FingerDefault.Action) {
        switch action {
        case .turnOff(let rearmGuide):
            defaults.set(false, forKey: AppSettings.allowFingerKey)
            if rearmGuide {
                AppSettings.forgetSpanGuideShown(.week)
                AppSettings.forgetSpanGuideShown(.day)
            }
        case .turnOnAgain:
            defaults.set(true, forKey: AppSettings.allowFingerKey)
        case .rebind:
            break
        }
        if let mark = device(), !mark.isEmpty {
            defaults.set(mark, forKey: Self.markKey)
        }
        onApply?(action)
    }

    /// One input to the state; the action it answers (at most one) is written at once — or, when a touch's lift decided it,
    /// on the main actor's next turn (`afterTheLift`).
    private func feed(_ input: Input, _ step: (inout FingerDefault) -> FingerDefault.Action?) {
        onInput?(input)
        guard let action = step(&state) else { return }
        origin = .app
        if input == .touchUp {
            afterTheLift(action)
        } else {
            apply(action)
        }
    }

    /// §4.8 (本人の選びは守る; C6): the window's watcher hears a lift inside `touchesEnded`, while UIKit is still delivering
    /// it, which can be before the control under it acts — the toolbar's 「指でも書く」 is a button-style Toggle that flips
    /// the value it reads at that touch-up. Written then, a Pencil tap on that switch, meant to turn it off, would find it
    /// off already and turn it on again as the person's. So an action a lift decided is written on the main actor's next turn, after
    /// that delivery, unless the person switched in between (`personSwitched`: their tap wins). It was decided with no
    /// touch down (C6), and the canvas takes the value at the screen's next update as before (`InkCanvasView` applies the
    /// drawing policy in `updateUIView`).
    private func afterTheLift(_ action: FingerDefault.Action) {
        Task { @MainActor [weak self] in
            guard let self, self.origin != .person else { return }
            self.apply(action)
        }
    }

    /// The watcher recognises alongside every recogniser (it never begins, so it holds nothing up).
    private final class Simultaneous: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// 1.4 (§2.1, §4.8): tells the screen the UIWindow it is in once the view is in one (`didMoveToWindow`), for
/// `PencilPhone.attach`. A clear view that takes no touch and is not in the accessibility tree.
struct PencilPhoneWindowReader: UIViewRepresentable {
    let onWindow: (UIWindow) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onWindow = onWindow
    }

    final class ReaderView: UIView {
        var onWindow: ((UIWindow) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window {
                onWindow?(window)
            }
        }
    }
}
