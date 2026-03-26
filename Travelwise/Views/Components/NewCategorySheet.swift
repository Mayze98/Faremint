import SwiftUI

struct NewCategorySheet: View {
    let existingCategories: [ExpenseCategory]
    let onSave: (ExpenseCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "tag.fill"
    @State private var selectedColorHex = "4ECDC4"
    @State private var showDuplicateError = false

    private let colorOptions: [(hex: String, label: String)] = [
        ("4ECDC4", "Teal"),
        ("FF6B6B", "Red"),
        ("45B7D1", "Sky"),
        ("96CEB4", "Sage"),
        ("FFEAA7", "Yellow"),
        ("DDA0DD", "Plum"),
        ("F7DC6F", "Gold"),
        ("98D8C8", "Mint"),
        ("E17055", "Coral"),
        ("6C5CE7", "Purple"),
        ("00B894", "Green"),
        ("FD79A8", "Pink"),
        ("74B9FF", "Blue"),
        ("A29BFE", "Lavender"),
        ("55EFC4", "Aqua"),
        ("636E72", "Grey"),
    ]

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

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                        ForEach(colorOptions, id: \.hex) { option in
                            Button {
                                selectedColorHex = option.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: option.hex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColorHex == option.hex {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2.5)
                                            Circle()
                                                .strokeBorder(Color(hex: option.hex), lineWidth: 1.5)
                                                .frame(width: 38, height: 38)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
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
                                            ? Color(hex: selectedColorHex).opacity(0.15)
                                            : Color(.systemGray6)
                                    )
                                    .foregroundStyle(
                                        selectedIcon == icon ? Color(hex: selectedColorHex) : .secondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                selectedIcon == icon ? Color(hex: selectedColorHex) : .clear,
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
                        let category = ExpenseCategory(customName: trimmedName, systemImage: selectedIcon, colorHex: selectedColorHex)
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
