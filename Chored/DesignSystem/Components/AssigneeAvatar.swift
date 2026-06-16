import SwiftUI

/// Assignee initials in a circle. `secondarySystemBackground` fill,
/// `secondaryLabel` text. Default 28pt per the Task Chip spec.
struct AssigneeAvatar: View {
    let initials: String
    var diameter: CGFloat = Theme.Size.assigneeAvatar

    var body: some View {
        Text(initials)
            .choredCaption()
            .foregroundStyle(Color(.secondaryLabel))
            .frame(width: diameter, height: diameter)
            .background(Color(.secondarySystemBackground))
            .clipShape(Circle())
            .accessibilityLabel("Assignee \(initials)")
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.sm) {
        AssigneeAvatar(initials: "RC")
        AssigneeAvatar(initials: "JD", diameter: 40)
    }
    .padding()
}
