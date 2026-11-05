import InkModel
import Layout
import SwiftUI

/// 設定 ›「週の始まり」 (1.2, docs/M7B_CONTRACT.md §10.4, O-2): the row with 自動・月曜・日曜, the footer, and
/// how many week pages the other form has. Per device (D16). A choice that changes the first day of
/// the week stops at a question first (`weekStartQuestion`), because week pages are separate pages:
/// what is written now stays out of sight until the person comes back. Only then the record is
/// written (`WeekStartChoice.choose`), and `CalendarRootScreen` switches on its `.onChange` (§10.5).
///
/// Screenshot mode stores nothing (§10.7): `screenshotWeekStart` stands in for the record.
struct WeekStartSettingsSection: View {
    /// The setting the question is about; nil = no question. The question itself sits on the form.
    @Binding var pending: WeekStartChoice.Setting?
    var screenshotWeekStart: WeekStart
    /// This device's page ids (`sync.allLocalPageIds()`), read when the row appears and after a switch.
    var pageIds: () -> [String]

    @AppStorage(AppSettings.weekStartKey) private var raw = ""
    @State private var otherPages: String?

    private var setting: WeekStartChoice.Setting {
        if ScreenshotMode.isActive {
            return screenshotWeekStart == .monday ? .monday : .sunday
        }
        return WeekStartChoice.Setting(rawValue: raw) ?? .monday
    }

    private var selection: Binding<WeekStartChoice.Setting> {
        Binding(get: { setting }, set: { choose($0) })
    }

    var body: some View {
        Section {
            Picker(L.text("settings.weekStart.title"), selection: selection) {
                Text(Self.automaticText(WeekStartChoice.launchAutomatic))
                    .tag(WeekStartChoice.Setting.auto)
                Text(WeekStartChoice.name(.monday))
                    .tag(WeekStartChoice.Setting.monday)
                Text(WeekStartChoice.name(.sunday))
                    .tag(WeekStartChoice.Setting.sunday)
            }
            // The same as 「予定の登録先」: a list on its own screen.
            .pickerStyle(.navigationLink)
            .onAppear(perform: refreshOtherPages)
            .onChange(of: raw) { refreshOtherPages() }
            .onChange(of: screenshotWeekStart) { refreshOtherPages() }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.text("settings.weekStart.footer"))
                if let otherPages {
                    Text(otherPages)
                }
            }
        }
    }

    private func refreshOtherPages() {
        otherPages = Self.otherPagesText(current: WeekStartChoice.resolve(setting), pageIds: pageIds())
    }

    /// A choice that keeps the first day of the week is written at once; one that changes it asks first,
    /// once the picker's list has gone back (an alert cannot come up during that transition).
    private func choose(_ next: WeekStartChoice.Setting) {
        guard next != setting else { return }
        if Self.confirmTarget(from: setting, to: next, automatic: WeekStartChoice.launchAutomatic) != nil {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(CalendarRootScreen.sheetGap))
                pending = next
            }
        } else if !ScreenshotMode.isActive {
            WeekStartChoice.choose(next)
        }
    }

    // MARK: - The words and the rule (tests call these)

    /// 「自動（日曜）」: what automatic gives today.
    static func automaticText(_ automatic: WeekStart) -> String {
        L.format("settings.weekStart.auto", WeekStartChoice.name(automatic))
    }

    /// The first day the choice leads to when it differs from today's; nil when it stays the same
    /// (Monday → 自動 that gives Monday asks nothing, §10.4).
    static func confirmTarget(from current: WeekStartChoice.Setting, to next: WeekStartChoice.Setting, automatic: WeekStart) -> WeekStart? {
        let old = current == .auto ? automatic : (current == .monday ? WeekStart.monday : .sunday)
        let new = next == .auto ? automatic : (next == .monday ? WeekStart.monday : .sunday)
        return old == new ? nil : new
    }

    /// The line under the footer: how many week pages the other form has; nil when it has none. The
    /// ids only are counted, so a page whose strokes were all erased counts too: it says 「週のページが」.
    static func otherPagesText(current: WeekStart, pageIds: [String]) -> String? {
        let pages = WeekStartImpact.weekPages(pageIds)
        let count = current == .monday ? pages.sunday : pages.monday
        guard count > 0 else { return nil }
        let other: WeekStart = current == .monday ? .sunday : .monday
        return L.plural("settings.weekStart.otherPages", count: count, WeekStartChoice.name(other), DateText.number(count, L.language))
    }

    static func confirmTitle(_ target: WeekStart) -> String {
        switch target {
        case .sunday: return L.text("settings.weekStart.confirm.title.sunday")
        case .monday: return L.text("settings.weekStart.confirm.title.monday")
        }
    }

    static func confirmMessage(_ target: WeekStart) -> String {
        switch target {
        case .sunday: return L.text("settings.weekStart.confirm.message.sunday")
        case .monday: return L.text("settings.weekStart.confirm.message.monday")
        }
    }

    static func confirmButton(_ target: WeekStart) -> String {
        switch target {
        case .sunday: return L.text("settings.weekStart.confirm.ok.sunday")
        case .monday: return L.text("settings.weekStart.confirm.ok.monday")
        }
    }
}

/// The question of `WeekStartSettingsSection` (§10.4): on the form, because a form keeps no off-screen
/// row alive. 〔日曜にする〕 writes the record; in screenshot mode, which stores nothing, it calls
/// `onScreenshotAnswer` instead (§10.7). 〔やめる〕 leaves everything as it was.
private struct WeekStartQuestion: ViewModifier {
    @Binding var pending: WeekStartChoice.Setting?
    /// Screenshot mode's week start (the record is not read there).
    var current: WeekStart
    var onScreenshotAnswer: (WeekStart) -> Void

    private var target: WeekStart? {
        pending.map(WeekStartChoice.resolve)
    }

    func body(content: Content) -> some View {
        content.alert(
            target.map(WeekStartSettingsSection.confirmTitle) ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: target
        ) { target in
            Button(WeekStartSettingsSection.confirmButton(target)) {
                answer(target)
            }
            Button(L.text("import.confirmLarge.cancel"), role: .cancel) {
                pending = nil
            }
        } message: { target in
            Text(WeekStartSettingsSection.confirmMessage(target))
        }
    }

    private func answer(_ target: WeekStart) {
        let choice = pending
        pending = nil
        if ScreenshotMode.isActive {
            if target != current { onScreenshotAnswer(target) }
        } else if let choice {
            WeekStartChoice.choose(choice)
        }
    }
}

extension View {
    /// The question of switching the week start (§10.4).
    func weekStartQuestion(pending: Binding<WeekStartChoice.Setting?>, current: WeekStart, onScreenshotAnswer: @escaping (WeekStart) -> Void) -> some View {
        modifier(WeekStartQuestion(pending: pending, current: current, onScreenshotAnswer: onScreenshotAnswer))
    }
}
