import SwiftUI

/// 「別の iCloud アカウントです」 (M4 contract §6.4, DESIGN §5.4): the local handwriting belongs to the
/// iCloud account that synced it first; a different account is signed in now, so the engine stopped
/// and asks. Keep the ink (it goes to the new account's iCloud), erase it (asked once more), or
/// later (nothing changes; the question comes back at the next launch).
extension View {
    func accountChangeDialog(isPresented: Binding<Bool>, onChoose: @escaping (AccountChangeChoice) -> Void) -> some View {
        modifier(AccountChangeDialogModifier(isPresented: isPresented, onChoose: onChoose))
    }
}

/// The confirmation dialog and the second alert behind `accountChangeDialog(isPresented:onChoose:)`.
struct AccountChangeDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onChoose: (AccountChangeChoice) -> Void

    @State private var confirmErase = false

    static let title = "別の iCloud アカウントです"
    static let message = "この iPad の手書きは、前に同期していた iCloud アカウントのものです。いまサインインしているアカウントで使い始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。"
    static let eraseTitle = "本当に消しますか？"
    static let eraseMessage = "この iPad の手書きを全て消して、新しいアカウントで始めます。この操作は元に戻せません。"

    func body(content: Content) -> some View {
        content
            .confirmationDialog(Self.title, isPresented: $isPresented, titleVisibility: .visible) {
                Button("手書きを残して使い始める") {
                    onChoose(.keepInk)
                }
                Button("手書きを消して使い始める", role: .destructive) {
                    // The second question is an alert; it can only appear once the dialog is gone
                    // (the same 0.35 s as the settings screen's double confirmation).
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.35))
                        confirmErase = true
                    }
                }
                Button("あとで", role: .cancel) {
                    onChoose(.later)
                }
            } message: {
                Text(Self.message)
            }
            .alert(Self.eraseTitle, isPresented: $confirmErase) {
                Button("消して始める", role: .destructive) {
                    onChoose(.eraseInk)
                }
                Button("キャンセル", role: .cancel) {
                    onChoose(.later)
                }
            } message: {
                Text(Self.eraseMessage)
            }
    }
}
