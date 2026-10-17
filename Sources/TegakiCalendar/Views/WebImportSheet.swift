import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The file picker of 「Web 版の手書きを取り込む」 (M4 contract §6.3): a `UIDocumentPickerViewController`
/// that opens JSON (and plain text, because the Files app sometimes types the web export as text)
/// as a copy, so the URL handed back is a temporary file the app may read.
struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView

        init(parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}

/// Where the import is (M4 contract §6.3): reading the file, importing (with progress), done, failed.
/// `done` carries whether the file was the app's own export (M6_CONTRACT §1.2, 0-12), which picks
/// the finished sentence.
enum WebImportPhase: Equatable {
    case reading
    case importing(done: Int, total: Int)
    case done(ImportOutcome, skipped: Int, isAppExport: Bool)
    case failed(String)

    /// Reading and importing: the sheet cannot be swiped away (the work would carry on behind it).
    var isInProgress: Bool {
        switch self {
        case .reading, .importing: return true
        case .done, .failed: return false
        }
    }
}

/// The sheet that shows the import's progress and result (M4 contract §6.3, §6.8). It has no state
/// of its own: `CalendarRootScreen` drives `phase` (file → `InkImport.parse` / `pages` →
/// `SyncEngine.importPages`) and shows the same result text as a toast after 「閉じる」. Since M6 the
/// door takes two formats (M6_CONTRACT §1.2): the web version's export and the app's own data file
/// (a restore); the title stays 「Web 版の手書きを取り込む」 (M6-4) and the finished sentence says
/// which one it was (`resultText(_:isAppExport:)`, 0-12).
struct WebImportSheet: View {
    var phase: WebImportPhase
    var onClose: () -> Void

    static let title = "Web 版の手書きを取り込む"

    // MARK: Texts (M4 contract §6.3; the owner uses them for the phases and the toast)

    /// `ParseError.notAnExport` (neither format, M6_CONTRACT §3.6).
    static let notAnExportText = "このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません"
    /// `ParseError.invalidJSON`.
    static let invalidJSONText = "ファイルを読めませんでした"
    /// `ParseError.unsupportedVersion(v)`.
    static func unsupportedVersionText(_ version: Int) -> String {
        "このファイルは新しい形式です（v\(version)）。アプリを更新してください"
    }
    /// `SyncEngine.importPages` threw.
    static func saveFailedText(_ error: Error) -> String {
        "保存できませんでした: \(error.localizedDescription)"
    }

    /// The result line: what was imported (the app's own data file 「手書きを取り込みました（…）」, the
    /// web version's 「Web 版の手書きを取り込みました（…）」; M6_CONTRACT §3.6, 0-12), or that everything
    /// was already there.
    static func resultText(_ outcome: ImportOutcome, isAppExport: Bool = false) -> String {
        if outcome.pagesChanged > 0 {
            let lead = isAppExport ? "手書きを取り込みました" : "Web 版の手書きを取り込みました"
            return "\(lead)（\(outcome.pagesChanged) ページ・\(outcome.strokesAdded) 本）"
        }
        return "取り込むものはありませんでした（すべて取り込み済みです）"
    }

    /// The second line, when pages were skipped (an old page id, no strokes); nil otherwise.
    static func skippedText(_ skipped: Int) -> String? {
        skipped > 0 ? "\(skipped) ページは対象外のため飛ばしました" : nil
    }

    /// The toast after the sheet closed: the result line, the skipped line under it when there is one.
    static func toastText(outcome: ImportOutcome, skipped: Int, isAppExport: Bool = false) -> String {
        if let second = skippedText(skipped) {
            return resultText(outcome, isAppExport: isAppExport) + "\n" + second
        }
        return resultText(outcome, isAppExport: isAppExport)
    }

    /// 「取り込んでいます… 3 / 12 ページ」 (no numbers while the file is still being read).
    static func progressText(_ phase: WebImportPhase) -> String {
        if case .importing(let done, let total) = phase {
            return "取り込んでいます… \(done) / \(total) ページ"
        }
        return "取り込んでいます…"
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
        }
        .interactiveDismissDisabled(phase.isInProgress)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .reading:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
            Text(Self.progressText(phase))
                .font(.body)
                .multilineTextAlignment(.center)

        case .importing(let done, let total):
            ProgressView(value: Double(min(done, total)), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)
            Text(Self.progressText(phase))
                .font(.body)
                .multilineTextAlignment(.center)

        case .done(let outcome, let skipped, let isAppExport):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.green)
            Text(Self.resultText(outcome, isAppExport: isAppExport))
                .font(.body)
                .multilineTextAlignment(.center)
            if let second = Self.skippedText(skipped) {
                Text(second)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            closeButton

        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.red)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            closeButton
        }
    }

    private var closeButton: some View {
        Button("閉じる", action: onClose)
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
    }
}
