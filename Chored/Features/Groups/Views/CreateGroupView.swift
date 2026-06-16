import SwiftUI

/// Create-group sheet. Name only (per spec). One primary action.
struct CreateGroupView: View {

    /// Returns true on success so the sheet can dismiss.
    let onCreate: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group name", text: $name)
                        .choredBody()
                        .submitLabel(.done)
                } footer: {
                    Text("For example: Apartment 4B, The Cottage, Maple Street.")
                        .choredCaption()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
        }
    }

    private func create() {
        isWorking = true
        Task {
            _ = await onCreate(name)
            isWorking = false
        }
    }
}
