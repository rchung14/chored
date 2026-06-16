import SwiftUI
import CloudKit
import UIKit

/// Group detail: members, invite (CKShare via system sheet), leave/delete.
struct GroupDetailView: View {

    let group: ChoreGroup
    let currentUser: User
    @ObservedObject var viewModel: GroupViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: SharePayload?
    @State private var confirmingDelete = false

    private var isOwner: Bool { viewModel.isOwner(group) }

    var body: some View {
        List {
            Section("Members") {
                ForEach(group.memberRecordNames, id: \.self) { recordName in
                    memberRow(recordName)
                }
            }

            Section {
                Button {
                    Task { await presentShare() }
                } label: {
                    Label("Invite a roommate", systemImage: "square.and.arrow.up")
                }
                .disabled(!group.canAddMember)
            } footer: {
                if !group.canAddMember {
                    Text("This group has reached the \(Constants.Limits.membersPerGroup)-member limit.")
                        .choredCaption()
                }
            }

            Section {
                if isOwner {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: { Text("Delete group") }
                } else {
                    Button(role: .destructive) {
                        Task { await viewModel.leave(group); dismiss() }
                    } label: { Text("Leave group") }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sharePayload) { payload in
            CloudSharingView(share: payload.share, container: payload.container, group: group)
        }
        .alert("Delete \(group.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(group); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the group and all of its tasks for everyone.")
        }
    }

    @ViewBuilder
    private func memberRow(_ recordName: String) -> some View {
        let isYou = recordName == currentUser.recordName
        let name = isYou ? currentUser.displayName : UserStore().cachedName(for: recordName) ?? "Roommate"
        HStack(spacing: Theme.Spacing.md) {
            AssigneeAvatar(initials: initials(for: name))
            Text(name + (isYou ? " (you)" : ""))
                .choredCallout()
                .foregroundStyle(Color(.label))
            if group.isOwner(recordName) {
                Spacer()
                Text("Owner")
                    .choredCaption()
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    private func initials(for name: String) -> String {
        User(recordName: "", displayName: name).initials
    }

    private func presentShare() async {
        guard let (share, container) = await viewModel.prepareShare(for: group) else { return }
        sharePayload = SharePayload(share: share, container: container)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

/// Wraps `UICloudSharingController` so the system manages share participants.
private struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let group: ChoreGroup

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(group: group) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let group: ChoreGroup
        init(group: ChoreGroup) { self.group = group }

        func itemTitle(for csc: UICloudSharingController) -> String? { group.name }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {}
    }
}
