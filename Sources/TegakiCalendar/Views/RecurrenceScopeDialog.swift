import SwiftUI

/// What the 「この回だけ／以降すべて」 question is about (M3b contract §4.4).
enum RecurrenceScopeKind {
    case save, delete
}

extension View {
    /// The question asked before a recurring event is saved or deleted (DESIGN §4.6): 「この回だけ」 →
    /// `.thisEvent`, 「以降すべて」 → `.futureEvents` (destructive for a deletion), 「キャンセル」.
    func recurrenceScopeDialog(isPresented: Binding<Bool>, kind: RecurrenceScopeKind, onChoose: @escaping (EventSpan) -> Void) -> some View {
        confirmationDialog(L.text("recurrence.title"), isPresented: isPresented, titleVisibility: .visible) {
            Button(L.text("recurrence.thisEvent")) { onChoose(.thisEvent) }
            Button(L.text("recurrence.futureEvents"), role: kind == .delete ? .destructive : nil) { onChoose(.futureEvents) }
            Button(L.text("event.cancel"), role: .cancel) {}
        } message: {
            switch kind {
            case .save:
                Text(L.text("recurrence.message.save"))
            case .delete:
                Text(L.text("recurrence.message.delete"))
            }
        }
    }
}
