import SwiftUI
import UIKit

/// 1.1 fix (TestFlight build 12; docs/M7A.md ずれ 46): the canvas's last events, kept for the whole
/// process so a TestFlight build can hand them over when the eraser did not go back to the pen
/// (設定 › 情報: hold 「バージョン」 → 「記録」 → 〔コピー〕). Written by every canvas's coordinator, always
/// (`probeNote`): the tokens of the UI tests' probe — PencilKit's Begin / End and drawing changes, the
/// touches on the paper, the eraser's report, the overlay, `A:<page kind>` when a canvas is attached
/// and `T:<tool>` when the tool changes — each with the device's uptime (s). Never what was written,
/// no page, no date, no id. The last `limit` are kept.
@MainActor
enum InkTrace {
    static let limit = 64
    private(set) static var entries: [String] = []

    static func note(_ token: String) {
        entries.append("\(token)@\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime))")
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }

    /// What the 「記録」 sheet shows and copies: the app's version, the OS, then the entries, oldest first.
    static var text: String {
        let device = UIDevice.current
        let header = "てがきカレンダー \(SettingsScreen.versionText) / \(device.systemName) \(device.systemVersion) / \(device.model)"
        return ([header] + entries).joined(separator: "\n")
    }

    /// 設定 shows the sheet only in a TestFlight build (its receipt is the sandbox one), never in
    /// screenshot mode, the simulator or an App Store build.
    static var isAvailable: Bool {
        !ScreenshotMode.isActive && Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

/// The 「記録」 sheet (TestFlight only): `InkTrace.text`, selectable, and 〔コピー〕 to paste it into a
/// message to the developer.
struct InkTraceSheet: View {
    let text: String
    var onDone: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copied ? "コピーしました" : "コピー") {
                        UIPasteboard.general.string = text
                        copied = true
                    }
                }
            }
        }
    }
}
