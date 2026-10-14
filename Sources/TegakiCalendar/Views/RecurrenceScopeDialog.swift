import SwiftUI

/// What the 「この回だけ／以降すべて」 question is about (M3b contract §4.4).
enum RecurrenceScopeKind {
    case save, delete
}

extension View {
    /// The question asked before a recurring event is saved or deleted (DESIGN §4.6): 「この回だけ」 →
    /// `.thisEvent`, 「以降すべて」 → `.futureEvents` (destructive for a deletion), 「キャンセル」.
    func recurrenceScopeDialog(isPresented: Binding<Bool>, kind: RecurrenceScopeKind, onChoose: @escaping (EventSpan) -> Void) -> some View {
        confirmationDialog("繰り返しの予定です", isPresented: isPresented, titleVisibility: .visible) {
            Button("この回だけ") { onChoose(.thisEvent) }
            Button("以降すべて", role: kind == .delete ? .destructive : nil) { onChoose(.futureEvents) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            switch kind {
            case .save:
                Text("この回だけ変更しますか？ 以降すべてに適用しますか？")
            case .delete:
                Text("この回だけ削除しますか？ 以降すべて削除しますか？")
            }
        }
    }
}
