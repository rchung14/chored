import SwiftUI

/// Empty state: tertiary-rendered SF symbol + single-line direction. No emoji,
/// no illustrations. Copy gives direction, not apology (DESIGN.md principle 5).
struct EmptyStateView: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color(.tertiaryLabel))
            Text(message)
                .choredBody()
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(systemImage: "checkmark.circle", message: "No tasks today — add one with +")
}
