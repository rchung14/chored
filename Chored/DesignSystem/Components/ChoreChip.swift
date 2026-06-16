import SwiftUI

/// Day-view task chip. The 3pt left color bar is the *only* task-color element
/// on the chip (chromatic silence rule). Everything else is achromatic system
/// color. Takes primitives so DesignSystem holds no domain logic.
struct ChoreChip: View {
    let name: String
    let assigneeName: String
    let assigneeInitials: String
    let metadata: String          // e.g. "Due today" or a time string
    let preset: TaskColorPreset

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            // 3pt full-height color bar.
            Rectangle()
                .fill(preset.background(for: scheme))
                .frame(width: Theme.Size.chipColorBarWidth)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(name)
                    .choredHeadline()
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text("\(assigneeName) · \(metadata)")
                    .choredSubheadline()
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Spacer(minLength: Theme.Spacing.sm)

            AssigneeAvatar(initials: assigneeInitials)
                .padding(.trailing, Theme.Spacing.md)
        }
        .frame(minHeight: Theme.Size.chipMinHeight)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(assigneeName), \(metadata)")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.sm) {
        ChoreChip(name: "Take out trash", assigneeName: "Ryan",
                  assigneeInitials: "RC", metadata: "Due today", preset: .sage)
        ChoreChip(name: "Vacuum living room", assigneeName: "Jordan",
                  assigneeInitials: "JD", metadata: "Due today", preset: .lavender)
    }
    .padding()
}
