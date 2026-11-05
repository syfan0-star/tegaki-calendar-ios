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

    static let title = L.text("account.title")
    static let message = L.text("account.message")
    static let eraseTitle = L.text("account.eraseTitle")
    static let eraseMessage = L.text("account.eraseMessage")

    func body(content: Content) -> some View {
        content
            .confirmationDialog(Self.title, isPresented: $isPresented, titleVisibility: .visible) {
                Button(L.text("account.keep")) {
                    onChoose(.keepInk)
                }
                Button(L.text("account.erase"), role: .destructive) {
                    // The second question is an alert; it can only appear once the dialog is gone
                    // (the same 0.35 s as the settings screen's double confirmation).
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.35))
                        confirmErase = true
                    }
                }
                Button(L.text("account.later"), role: .cancel) {
                    onChoose(.later)
                }
            } message: {
                Text(Self.message)
            }
            .alert(Self.eraseTitle, isPresented: $confirmErase) {
                Button(L.text("account.eraseConfirm"), role: .destructive) {
                    onChoose(.eraseInk)
                }
                Button(L.text("account.cancel"), role: .cancel) {
                    onChoose(.later)
                }
            } message: {
                Text(Self.eraseMessage)
            }
    }
}
