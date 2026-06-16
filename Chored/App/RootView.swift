import SwiftUI

/// Top-level navigation gate. Routes between the iCloud blocking screen, the
/// one-time display-name prompt, and the main two-tab app.
struct RootView: View {

    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// 0 = Calendar, 1 = Groups. Deep links select Calendar.
    @State private var selectedTab = 0
    /// Bumped on remote change / deep link so feature views can refresh.
    @State private var refreshToken = UUID()

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.2), value: session.phase)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await session.handleForeground() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppDelegate.didReceiveRemoteChange)) { note in
                if note.object is URL { selectedTab = 0 }   // deep link → Calendar
                refreshToken = UUID()
                Task { await session.handleForeground() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .loading:
            ProgressView().controlSize(.large)

        case .iCloudUnavailable:
            ICloudUnavailableView()

        case .needsDisplayName:
            DisplayNamePromptView()

        case .ready(let user):
            MainTabView(currentUser: user, selectedTab: $selectedTab)
                .id(refreshToken)
        }
    }
}

/// Blocking screen when there is no iCloud account and no cached identity.
private struct ICloudUnavailableView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "icloud.slash",
            message: "Sign in to iCloud in Settings to use Chored."
        )
    }
}

/// One-time display-name prompt.
private struct DisplayNamePromptView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var name = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Text("What should we call you?")
                .choredTitle2()
                .foregroundStyle(Color(.label))
            Text("Your roommates will see this name on tasks.")
                .choredSubheadline()
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { save() }
            Button(action: save) {
                Text("Continue")
                    .choredHeadline()
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouchTarget)
                    .background(Color(.label))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }

    private func save() { Task { await session.saveDisplayName(name) } }
}

/// Two-tab shell: Calendar + Groups.
private struct MainTabView: View {
    let currentUser: User
    @Binding var selectedTab: Int
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarRootView(container: container, currentUser: currentUser)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(0)

            GroupListView(container: container, currentUser: currentUser)
                .tabItem { Label("Groups", systemImage: "person.2") }
                .tag(1)
        }
    }
}
