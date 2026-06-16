import SwiftUI

/// Lists the user's groups (owned + joined). Primary action: create a group.
struct GroupListView: View {

    let currentUser: User
    private let container: AppContainer
    @StateObject private var viewModel: GroupViewModel
    @State private var showingCreate = false

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: GroupViewModel(
            repository: container.groupRepository,
            currentUser: currentUser
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.groups.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        message: "No groups yet — create one with +"
                    )
                } else {
                    groupList
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!viewModel.canCreateGroup)
                    .accessibilityLabel("Create group")
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateGroupView { name in
                    let ok = await viewModel.createGroup(name: name)
                    if ok { showingCreate = false }
                    return ok
                }
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task { await viewModel.load() }
        }
    }

    private var groupList: some View {
        List {
            ForEach(viewModel.groups) { group in
                NavigationLink {
                    GroupDetailView(group: group, currentUser: currentUser, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(group.name)
                            .choredTitle2()
                            .foregroundStyle(Color(.label))
                        Text(memberSummary(group))
                            .choredSubheadline()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .swipeActions(edge: .trailing) {
                    if viewModel.isOwner(group) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(group) }
                        } label: { Label("Delete", systemImage: "trash") }
                    } else {
                        Button {
                            Task { await viewModel.leave(group) }
                        } label: { Label("Leave", systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: viewModel.groups)
    }

    private func memberSummary(_ group: ChoreGroup) -> String {
        let count = group.memberRecordNames.count
        let role = viewModel.isOwner(group) ? "owner" : "member"
        return "\(count) member\(count == 1 ? "" : "s") · \(role)"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
