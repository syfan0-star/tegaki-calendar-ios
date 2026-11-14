import Layout
import SwiftUI

// 1.3 (docs/M7C_CONTRACT.md §3.14, §3.16, §8.1 N-4 … N-8; B_DESIGN.md §3.1 「初めての案内」): the first-time guide
// of the joined pages. The first time this device opens a kind joined sideways (week or day, the setting on), a
// small dark card at the top edge of the paper (right under the all-day band; at the bottom it would cover the
// day's free memo) tells how to slide to the next page: one finger with 「指でも書く」 off, two fingers with it on
// (a finger then writes). It goes after 8 seconds or at a touch, and comes once per device and kind
// (`AppSettings.spanGuideShown`, written once the card was seen: its 8 seconds or a touch, not a sheet or a question
// over it; the lead's decision 9 of wave C1). Never in screenshot mode (where `--screenshot-span-guide` shows it for the
// photo, §3.12) nor with the setting off. Where the card sits and when a page counts as opened is the screen's
// (`CalendarRootScreen`, S5's screen wave); this file holds the rules, the words and the card.

/// The first-time guide's rules and words (pure functions, fixed in SettingsPageSectionTests).
enum SpanGuide {
    /// §3.16: the card stays 8 seconds (not one of the numbers the prototype may change).
    static let duration: TimeInterval = 8

    /// The kinds joined sideways in 1.3 (D2): week and day. Month (1.7) and year (1.8) stay one page at a time
    /// and have no guide yet.
    static let joinedKinds: [PageKind] = [.week, .day]

    /// The fixed text of §8.1: N-4 (week) and N-6 (day) with 「指でも書く」 off, where one finger slides the band;
    /// N-5 and N-7 with it on, where a finger writes and two fingers slide. nil for a kind that is not joined.
    static func text(kind: PageKind, allowFinger: Bool) -> String? {
        switch (kind, allowFinger) {
        case (.week, false): return L.text("span.guide.week.oneFinger")
        case (.week, true): return L.text("span.guide.week.twoFingers")
        case (.day, false): return L.text("span.guide.day.oneFinger")
        case (.day, true): return L.text("span.guide.day.twoFingers")
        case (.month, _), (.year, _): return nil
        }
    }

    /// Whether the guide of `kind` is due when a page of that kind opens: a joined kind (`joinedKinds`), this
    /// device's setting on (`setting`: `AppSettings.pageSpan`, §3.14 「設定オフでは出さない」, read here and not
    /// left to the caller), shown joined (`joined`: the kind not fallen back to one page by stage 2, §3.15), not
    /// shown on this device yet (`shown`), and neither screenshot mode nor the XCTest host (like the pinch hint's
    /// `CalendarRootScreen.pinchHintDue`; the host would write the record without anyone seeing the card).
    static func isDue(kind: PageKind, setting: Bool, joined: Bool, shown: Bool, screenshot: Bool, testHost: Bool) -> Bool {
        joinedKinds.contains(kind) && setting && joined && !shown && !screenshot && !testHost
    }

    /// §3.15 stage 2 (N-8): the one-time notice when a kind falls back to one page at a time because its window
    /// holds too many strokes. The screen shows it (S5's screen wave); the words are here with the guide's.
    static let stageTwoNotice = L.text("span.stageTwo.notice")
}

/// The guide's state on the screen: the card that is up, its 8 seconds and this device's record. The 8 seconds
/// go through `sleep` (the real one by default; the tests pass `TestSleeper`, §3.16, so no test waits for real).
/// `clock` completes the shape §3.16 gives every new timer (`SyncEngine.init`'s `sleep:` and `clock:`, the real
/// ones by default); the guide reads no time of day today, only the 8 seconds' wait.
@MainActor
final class SpanGuideModel: ObservableObject {
    struct Card: Equatable {
        let kind: PageKind
        let text: String
        /// Counts the cards of this model: the timer of a card already gone leaves a later card alone.
        let serial: Int
        /// False only for screenshot mode's card (`showForPhoto`), which stays for the photo.
        let timed: Bool
    }

    /// The card on screen; nil when none is.
    @Published private(set) var card: Card?

    private let screenshot: Bool
    private let testHost: Bool
    private let sleep: @MainActor (TimeInterval) async -> Void
    private let clock: () -> Date
    private var serial = 0
    private var timer: Task<Void, Never>?

    /// `screenshot` and `testHost` are the process's by default (the tests pass false to see the card).
    init(
        screenshot: Bool = ScreenshotMode.isActive,
        testHost: Bool = SyncEngine.isTestHost,
        sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
        clock: @escaping () -> Date = Date.init
    ) {
        self.screenshot = screenshot
        self.testHost = testHost
        self.sleep = sleep
        self.clock = clock
    }

    /// A page of `kind` is on screen (`joined`: shown joined sideways, not fallen back by stage 2) with nothing
    /// over it: shows the card when it is due (`SpanGuide.isDue`, which also reads this device's setting
    /// `AppSettings.pageSpan`). Returns whether it was shown. The text follows 「指でも書く」 (`allowFinger`) as it is now.
    /// 1.3 (the lead's decision 9 of wave C1, docs/M7C.md; the rest of review J2): the card is recorded for this device
    /// and kind only once the person saw it — it stayed its 8 seconds, or they closed it (`close`) — and not here, so a
    /// card a sheet or a question took away (`dismiss`) comes again at the next calm moment; once seen, never again.
    /// A card of `kind` already up stays with its own seconds (it is not shown again over itself).
    @discardableResult
    func showIfDue(_ kind: PageKind, joined: Bool, allowFinger: Bool) -> Bool {
        guard SpanGuide.isDue(kind: kind, setting: AppSettings.pageSpan, joined: joined,
                              shown: AppSettings.spanGuideShown(kind), screenshot: screenshot, testHost: testHost),
              let text = SpanGuide.text(kind: kind, allowFinger: allowFinger) else { return false }
        if let up = card, up.kind == kind, up.timed { return false }
        present(kind, text, timed: true)
        return true
    }

    /// Screenshot mode's `--screenshot-span-guide` (§3.12): the card of `kind` without the record and without
    /// the 8 seconds, so it stays for the photo. Nothing for a kind that is not joined.
    func showForPhoto(_ kind: PageKind, allowFinger: Bool) {
        guard let text = SpanGuide.text(kind: kind, allowFinger: allowFinger) else { return }
        present(kind, text, timed: false)
    }

    /// The person closed the card: a touch on it or on the paper (the pen, a finger's tap, drag or pinch). The card
    /// they saw is recorded for this device and its kind (decision 9); the photo's card (`showForPhoto`) records
    /// nothing. Then it goes as `dismiss` takes it.
    func close() {
        if let up = card {
            AppSettings.markSpanGuideShown(up.kind)
        }
        dismiss()
    }

    /// The card goes at once without counting as seen (decision 9): a sheet or a question came over it (1.2.2's age
    /// range sheet is one of the sheets), or the screen left the joined page (another kind, the setting off, stage 2,
    /// 「消して始める」). Nothing is recorded, so it comes again at the next calm moment. Nothing when no card is up.
    func dismiss() {
        timer?.cancel()
        timer = nil
        if card != nil {
            card = nil
        }
    }

    private func present(_ kind: PageKind, _ text: String, timed: Bool) {
        timer?.cancel()
        timer = nil
        serial += 1
        let shown = Card(kind: kind, text: text, serial: serial, timed: timed)
        card = shown
        guard timed else { return }
        let sleep = self.sleep
        timer = Task { @MainActor [weak self] in
            await sleep(SpanGuide.duration)
            // A cancelled real sleep returns at once; only the card this timer belongs to goes. It stayed its
            // 8 seconds, so it was seen (decision 9).
            guard let self, self.card?.serial == shown.serial else { return }
            self.card = nil
            self.timer = nil
        }
    }
}

/// The card itself (B_DESIGN.md §3.1, the black card of b2-iphone.svg; the prototype's `SpanPrototypeGuideCard`):
/// white footnote text on a dark rounded card at most 520 pt wide. The screen lays it over the top edge of the
/// paper. It goes at any touch on it (§3.14 「触れても消える」), not only at a tap: the first touch down of a
/// finger or the Pencil, so a stroke or a drag begun on the card takes it away too (a tap alone would leave it
/// for the 8 seconds, and the card covers the paper there). The tap stays for VoiceOver's activation. A touch is the
/// person closing it (`SpanGuideModel.close`): the card counts as seen.
struct SpanGuideView: View {
    @ObservedObject var model: SpanGuideModel

    /// For the UI tests and the photos (§10.3, §10.5).
    static let accessibilityIdentifier = "span.guide"

    var body: some View {
        if let card = model.card {
            Text(card.text)
                .font(.footnote)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 520)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in model.close() })
                .onTapGesture { model.close() }
                .accessibilityIdentifier(Self.accessibilityIdentifier)
                .id(card.serial)
                .transition(.opacity)
        }
    }
}
