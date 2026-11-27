import SwiftUI

/// 設定 ›「メモ欄の紙」 (1.4.2, docs/R1_4_2_CONTRACT.md §4.2, 0f-20): one row with 罫線・ドット方眼・無地 on its own screen
/// (`.navigationLink`, the shape of 「週の始まり」), no header, one footnote. The first element of `SettingsScreen.inputSections`,
/// so on the sheet it sits right below 「祝日」 while the `Form`'s nine elements stay 1.3's (SettingsPageSectionTests; 1.4.1's
/// 「利き手」 is inside `inputSections` for the same reason). One setting for every memo area, per device; read only too
/// (docs/DESIGN.md: allowed while read only).
///
/// A choice outside screenshot mode is stored for this device first, then made the pattern in force
/// (`MemoPaperStyle.set`, which redraws every paper); screenshot mode stores nothing and only sets it, so the UI test sees the
/// paper change without leaving a value on the simulator (`SettingsScreen.handChanged`'s shape).
struct MemoPaperSettingsSection: View {
    /// The row's value as the sheet opens: the pattern in force (`MemoPaperStyle.current`: the stored one, or screenshot
    /// mode's `--screenshot-memo-paper`), then the last choice.
    @State private var style: MemoPaperStyle = MemoPaperStyle.current

    private var selection: Binding<MemoPaperStyle> {
        Binding(get: { style }, set: { choose($0) })
    }

    var body: some View {
        Section {
            Picker(Self.title, selection: selection) {
                ForEach(MemoPaperStyle.allCases, id: \.self) { choice in
                    Text(Self.name(choice)).tag(choice)
                }
            }
            // The same as 「週の始まり」 and 「予定の登録先」: a list on its own screen.
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier(Self.identifier)
        } footer: {
            Text(Self.footer)
        }
    }

    private func choose(_ next: MemoPaperStyle) {
        guard next != style else { return }
        style = next
        Self.changed(to: next, screenshot: ScreenshotMode.isActive)
    }

    // MARK: - The words and the rule (tests call these)

    /// The row's title (and its screen's).
    static let title = L.text("settings.memoPaper.title")
    /// The footnote: what changes and that the handwriting stays.
    static let footer = L.text("settings.memoPaper.footer")
    /// The row, for the UI tests.
    static let identifier = "settings.memoPaper"

    /// The name of a choice: 「罫線」, 「ドット方眼」, 「無地」.
    static func name(_ style: MemoPaperStyle) -> String {
        switch style {
        case .ruled: return L.text("settings.memoPaper.ruled")
        case .dots: return L.text("settings.memoPaper.dots")
        case .plain: return L.text("settings.memoPaper.plain")
        }
    }

    /// The pattern was switched to `value`: outside screenshot mode it is stored for this device (`AppSettings.memoPaperKey`)
    /// and then made the pattern in force; screenshot mode stores nothing and only makes it the pattern in force.
    @MainActor static func changed(to value: MemoPaperStyle, screenshot: Bool, _ defaults: UserDefaults = AppSettings.defaults) {
        if !screenshot {
            defaults.set(value.rawValue, forKey: AppSettings.memoPaperKey)
        }
        MemoPaperStyle.set(value)
    }
}

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §6.1, MemoPaperUITests): screenshot mode's `memo-paper.state` for the UI tests, as `l10n.state`:
/// 1 × 1 pt, clear, in the accessibility tree only, taking no touch. Its label is "style=<ruled|dots|plain>", the pattern the
/// papers were last told (`MemoPaperStyle.current` at each `MemoPaperStyle.didChange`, the notice every `PaperView` follows).
/// Nothing outside screenshot mode.
struct MemoPaperShotState: View {
    static let identifier = "memo-paper.state"

    @State private var style: MemoPaperStyle = MemoPaperStyle.current

    static func label(_ style: MemoPaperStyle) -> String {
        "style=\(style.rawValue)"
    }

    var body: some View {
        if ScreenshotMode.isActive {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(Self.identifier)
                .accessibilityLabel(Self.label(style))
                .allowsHitTesting(false)
                .padding(.leading, 8)
                .onReceive(NotificationCenter.default.publisher(for: MemoPaperStyle.didChange)) { _ in
                    style = MemoPaperStyle.current
                }
                .onAppear { style = MemoPaperStyle.current }
        }
    }
}
