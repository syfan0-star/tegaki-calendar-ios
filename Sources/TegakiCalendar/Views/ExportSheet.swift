import InkModel
import Layout
import SwiftUI

/// Where the export is (M6_CONTRACT §3.2): choosing one of the two exports, building it (with the
/// JSON's page progress; the PDF shows a spinner), done (the file, ready to share), failed.
enum ExportPhase: Equatable {
    /// The two buttons.
    case choose
    /// In progress (the PDF stays at 0 / 1: a spinner).
    case building(ExportKind, done: Int, total: Int)
    /// The checkmark, the file name and size, 〔共有…〕〔閉じる〕.
    case done(ExportResult)
    /// The triangle, the red text, 〔閉じる〕.
    case failed(String)

    /// Building: the sheet cannot be swiped away (the work would carry on behind it).
    var isInProgress: Bool {
        if case .building = self { return true }
        return false
    }
}

/// The sheet of 設定 › データ › 「手書きを書き出す」 (M6_CONTRACT §3.2, D2; the same shape as
/// `WebImportSheet`): it has no state of its own, `CalendarRootScreen` drives `phase`
/// (`.choose` → `onChoose(kind)` → `ExportBuilder` → `.done` / `.failed`) and shows a failure's
/// text as a toast after 「閉じる」. The finished file is handed out with a `ShareLink` (§2.4, 0-10,
/// M6-7): a file URL, so 「ファイルに保存」, AirDrop, メール and the apps that open the type are
/// offered; on an iPad SwiftUI anchors the popover to the button. The words are static pure
/// functions so `ExportSheetTests` can pin them (§7.2). New words say 「この端末」, never 「この iPad」
/// (the sheet also shows on an iPhone).
struct ExportSheet: View {
    var phase: ExportPhase
    /// `PageNavigation.title(kind, focus:)` of the page on the screen, e.g. 「2026年10月」.
    var pageTitle: String
    var pageKind: PageKind
    var onChoose: (ExportKind) -> Void
    var onClose: () -> Void

    // MARK: Texts (M6_CONTRACT §3.2 / §3.6; the owner uses `failureText` for the toast too)

    static let title = "手書きを書き出す"
    static let jsonTitle = "データファイル（JSON、すべてのページ）"
    static let jsonNote = "この端末に保存されている手書きをすべて 1 つのファイルにまとめます。設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。"
    static let pdfTitle = "このページを PDF"

    /// 「いま開いているページ（2026年10月・月）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。」
    static func pdfNote(pageTitle: String, kind: PageKind) -> String {
        "いま開いているページ（\(pageTitle)・\(AppExport.kindLabel(kind))）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。"
    }

    /// `.building(.json, 3, 12)` → 「書き出しています… 3 / 12 ページ」, `.building(.pdf, …)` →
    /// 「PDF を作っています…」, anything else → "".
    static func progressText(_ phase: ExportPhase) -> String {
        guard case .building(let kind, let done, let total) = phase else { return "" }
        switch kind {
        case .json: return "書き出しています… \(done) / \(total) ページ"
        case .pdf: return "PDF を作っています…"
        }
    }

    static let doneTitle = "書き出しました"

    /// JSON 「てがきカレンダー 手書き 2026-10-17.json（12 ページ・1.2 MB）」, PDF 「てがきカレンダー 2026年10月 月.pdf（1.2 MB）」.
    static func doneText(_ result: ExportResult) -> String {
        switch result.kind {
        case .json: return "\(result.fileName)（\(result.pageCount) ページ・\(byteText(result.byteCount))）"
        case .pdf: return "\(result.fileName)（\(byteText(result.byteCount))）"
        }
    }

    /// Under 1,024 「512 B」, under 1 MB 「512 KB」 (whole kilobytes), from 1 MB 「1.2 MB」 (one decimal;
    /// 1024-based throughout).
    static func byteText(_ count: Int) -> String {
        if count < 1_024 { return "\(count) B" }
        if count < 1_048_576 { return "\(count / 1_024) KB" }
        let tenths = Int((Double(count) / 1_048_576 * 10).rounded())
        return "\(tenths / 10).\(tenths % 10) MB"
    }

    static let shareTitle = "共有…"
    static let closeTitle = "閉じる"

    /// `ExportError.nothingToExport`.
    static let nothingToExportText = "書き出す手書きがありません"
    /// `ExportError.writeFailed(detail)`.
    static func writeFailedText(_ detail: String) -> String {
        "ファイルを書けませんでした: \(detail)"
    }
    /// `ExportError.renderFailed`.
    static let renderFailedText = "PDF を作れませんでした"

    /// The red line of `.failed` and the toast after it closed (§2.5): nil for `.cancelled` (the sheet
    /// just closes), 「書き出せませんでした: …」 for an error that is not an `ExportError`.
    static func failureText(_ error: Error) -> String? {
        switch error as? ExportError {
        case .nothingToExport: return nothingToExportText
        case .writeFailed(let detail): return writeFailedText(detail)
        case .renderFailed: return renderFailedText
        case .cancelled: return nil
        case .none: return "書き出せませんでした: \(error.localizedDescription)"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(Self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .choose = phase {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Self.closeTitle, action: onClose)
                    }
                }
            }
        }
        .interactiveDismissDisabled(phase.isInProgress)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .choose:
            chooseButton(Self.jsonTitle, note: Self.jsonNote, kind: .json)
            chooseButton(Self.pdfTitle, note: Self.pdfNote(pageTitle: pageTitle, kind: pageKind), kind: .pdf)

        case .building(let kind, let done, let total):
            switch kind {
            case .json:
                ProgressView(value: Double(min(done, total)), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 360)
            case .pdf:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
            }
            Text(Self.progressText(phase))
                .font(.body)
                .multilineTextAlignment(.center)

        case .done(let result):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.green)
            Text(Self.doneTitle)
                .font(.headline)
            Text(Self.doneText(result))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // §2.4: a file URL; iPad shows the popover anchored to this button (0-10).
            ShareLink(
                item: result.url,
                preview: SharePreview(result.fileName, image: Image(systemName: result.kind == .pdf ? "doc.richtext" : "doc.text"))
            ) {
                Label(Self.shareTitle, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Button(Self.closeTitle, action: onClose)
                .buttonStyle(.bordered)

        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.red)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
            Button(Self.closeTitle, action: onClose)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
    }

    /// One of the two large choices: the title in semibold, the one-line explanation under it, the
    /// whole row tappable (§3.2).
    private func chooseButton(_ title: String, note: String, kind: ExportKind) -> some View {
        Button {
            onChoose(kind)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
