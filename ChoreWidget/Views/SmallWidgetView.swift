import SwiftUI
import WidgetKit

/// Small widget: count of incomplete tasks due today + next task name + a color
/// bar for that next task. Achromatic except the single color bar.
struct SmallWidgetView: View {
    let entry: ChoreEntry
    @Environment(\.colorScheme) private var scheme

    private var next: ChoreTask? { entry.tasks.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(entry.tasks.count)")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color(.label))
            Text(entry.tasks.count == 1 ? "task today" : "tasks today")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))

            Spacer(minLength: 0)

            if let next {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(WidgetPalette.color(for: next.colorPreset, scheme: scheme))
                        .frame(width: 3)
                    Text(next.name)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)
                }
                .frame(maxHeight: 44)
            } else {
                Text("All done")
                    .font(.headline)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
