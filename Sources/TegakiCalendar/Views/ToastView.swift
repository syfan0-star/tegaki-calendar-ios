import SwiftUI

/// A short message at the bottom of the screen (M3b contract §4.9).
struct ToastMessage: Equatable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var isError: Bool = false
}

/// The capsule that shows a `ToastMessage` above the toolbar. `CalendarRootScreen` shows it for
/// `duration` seconds (`errorDuration` for an error) and then removes it.
struct ToastView: View {
    var message: ToastMessage

    static let duration: TimeInterval = 3
    static let errorDuration: TimeInterval = 6

    var body: some View {
        HStack(spacing: 8) {
            if message.isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
            }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(message.isError ? Color.red.opacity(0.45) : Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
