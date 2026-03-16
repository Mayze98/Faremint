import SwiftUI

struct ProfileView: View {
    @AppStorage("userName") private var userName = "Traveler"
    @State private var editingName = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section("Display Name") {
                TextField("Your name", text: $editingName)
                    .focused($isFocused)
            }

            Section {
                Text("This name appears in your trip bubbles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editingName = userName
        }
        .onDisappear {
            if !editingName.trimmingCharacters(in: .whitespaces).isEmpty {
                userName = editingName.trimmingCharacters(in: .whitespaces)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
