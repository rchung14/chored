import SwiftUI
import WidgetKit
import AppIntents

/// Medium widget: up to 5 incomplete tasks due today. Each row has a color bar,
/// task name, assignee initial, and a checkmark button wired to
/// `CompleteTaskIntent` so the task completes without opening the app.
struct MediumWidgetView: View {
    let entry: ChoreEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if entry.tasks.isEmpty {
                Spacer()
                Text("No tasks today")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(5)) { task in
                    row(task)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ task: ChoreTask) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(WidgetPalette.color(for: task.colorPreset, scheme: scheme))
                .frame(width: 3, height: 24)

            Text(task.name)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(initials(for: task.assigneeRecordName))
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(width: 22, height: 22)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

            Button(intent: CompleteTaskIntent(taskId: task.id)) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.name)")
        }
    }

    private func initials(for recordName: String) -> String {
        let name = entry.assigneeNames[recordName] ?? "?"
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let s = String(parts).uppercased()
        return s.isEmpty ? "?" : s
    }
}
