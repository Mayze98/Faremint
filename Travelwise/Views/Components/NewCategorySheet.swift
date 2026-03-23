import SwiftUI

struct NewCategorySheet: View {
    let existingCategories: [ExpenseCategory]
    let onSave: (ExpenseCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "tag.fill"
    @State private var showDuplicateError = false

    private let iconOptions: [String] = [
        "fork.knife",
        "cup.and.saucer.fill",
        "cart.fill",
        "bag.fill",
        "ticket.fill",
        "gift.fill",
        "airplane",
        "bed.double.fill",
        "car.fill",
        "tram.fill",
        "bus.fill",
        "fuelpump.fill",
        "map.fill",
        "camera.fill",
        "figure.walk",
        "mappin.and.ellipse",
        "umbrella.fill",
        "sun.max.fill",
        "snowflake",
        "leaf.fill",
        "cross.case.fill",
        "gamecontroller.fill",
        "music.note.list",
        "pawprint.fill"
    ]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicate: Bool {
        existingCategories.contains { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, _ in
                            showDuplicateError = false
                        }

                    if showDuplicateError && isDuplicate {
                        Text("A category with this name already exists.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        selectedIcon == icon
                                            ? Theme.accentTeal.opacity(0.15)
                                            : Color(.systemGray6)
                                    )
                                    .foregroundStyle(
                                        selectedIcon == icon ? Theme.accentTeal : .secondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                selectedIcon == icon ? Theme.accentTeal : .clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isDuplicate {
                            showDuplicateError = true
                            return
                        }
                        let category = ExpenseCategory(customName: trimmedName, systemImage: selectedIcon)
                        onSave(category)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NewCategorySheet(existingCategories: BaseCategory.allCases.map { ExpenseCategory(base: $0) }) { _ in }
}
