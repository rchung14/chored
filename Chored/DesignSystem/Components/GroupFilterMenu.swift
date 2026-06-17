import SwiftUI

/// A visible, labeled group filter (replaces a bare toolbar icon). Shows the
/// current selection inline — "Filter: All groups ⌄" — and opens a menu to
/// switch. Presentational only: takes plain option DTOs and a binding.
struct GroupFilterMenu: View {

    struct Option: Identifiable, Equatable {
        let id: String
        let name: String
    }

    let options: [Option]
    /// nil = all groups.
    @Binding var selectedID: String?

    private var currentName: String {
        guard let id = selectedID else { return "All groups" }
        return options.first { $0.id == id }?.name ?? "All groups"
    }

    var body: some View {
        Menu {
            Picker("Group", selection: Binding(
                get: { selectedID ?? "" },
                set: { selectedID = $0.isEmpty ? nil : $0 }
            )) {
                Text("All groups").tag("")
                ForEach(options) { Text($0.name).tag($0.id) }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text("Filter:")
                    .choredSubheadline()
                    .foregroundStyle(Color(.secondaryLabel))
                Text(currentName)
                    .choredSubheadline()
                    .foregroundStyle(Color(.systemBlue))
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemBlue))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: Theme.Size.minTouchTarget)
        }
        .accessibilityLabel("Filter by group, currently \(currentName)")
    }
}

#Preview {
    GroupFilterMenu(
        options: [.init(id: "1", name: "Apartment 4B"), .init(id: "2", name: "The Cottage")],
        selectedID: .constant(nil)
    )
    .padding()
}
