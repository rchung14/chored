import SwiftUI

/// Floating action button. 52pt circle, `label` background (inverts with shell),
/// `plus` glyph in `systemBackground`. Positioned by the caller; this component
/// only renders the button and its shadow.
struct FABButton: View {
    var systemImage: String = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: Theme.Size.fab, height: Theme.Size.fab)
                .background(Color(.label))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.20), radius: 8)
        }
        .accessibilityLabel("Add task")
    }
}

#Preview {
    FABButton {}
        .padding(Theme.Spacing.lg)
}
