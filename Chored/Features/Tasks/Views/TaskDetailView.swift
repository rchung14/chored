import SwiftUI
import UIKit

/// Task detail: assignee, next due date, last 5 completions, complete + delete.
struct TaskDetailView: View {

    @State var task: ChoreTask
    let group: ChoreGroup?
    @ObservedObject var viewModel: TaskViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private var assigneeName: String { viewModel.displayName(for: task.assigneeRecordName) }

    var body: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.md) {
                    AssigneeAvatar(
                        initials: User(recordName: "", displayName: assigneeName).initials,
                        diameter: 44
                    )
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(assigneeName)
                            .choredHeadline()
                            .foregroundStyle(Color(.label))
                        Text(nextDueText)
                            .choredSubheadline()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)

                if !task.description.isEmpty {
                    Text(task.description)
                        .choredBody()
                        .foregroundStyle(Color(.label))
                }
            }

            Section("Recent activity") {
                if viewModel.recentLogs.isEmpty {
                    Text("No completions yet.")
                        .choredCallout()
                        .foregroundStyle(Color(.secondaryLabel))
                } else {
                    ForEach(viewModel.recentLogs) { log in
                        HStack {
                            Text(viewModel.displayName(for: log.completedByRecordName))
                                .choredCallout()
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text(log.completedAt.formatted(date: .abbreviated, time: .shortened))
                                .choredCaption()
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
            }

            Section {
                Button {
                    complete()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
                .disabled(task.isComplete)

                if viewModel.canDelete(task, group: group) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: { Text("Delete task") }
                }
            }
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadLogs(for: task) }
        .alert("Delete \(task.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(task); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var nextDueText: String {
        if let next = task.nextOccurrence(onOrAfter: Date()) {
            return "Next due \(next.formatted(date: .abbreviated, time: .omitted))"
        }
        return "No upcoming date"
    }

    private func complete() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            if let updated = await viewModel.complete(task) {
                task = updated
            }
        }
    }
}
