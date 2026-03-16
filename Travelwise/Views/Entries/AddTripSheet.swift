import SwiftUI

struct AddTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var budget = ""
    @AppStorage("currencyCode") private var currencyCode = "USD"
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now.addingTimeInterval(7 * 24 * 3600)
    @State private var selectedColorIndex = 0
    @State private var customCategoryName = ""
    @State private var customCategories: [ExpenseCategory] = []

    private var budgetValue: Double {
        Double(budget) ?? 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && budgetValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip name", text: $name)
                    TextField("Budget", text: $budget)
                        .keyboardType(.decimalPad)
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("Set end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(Array(Theme.bubblePalette.enumerated()), id: \.offset) { index, hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if index == selectedColorIndex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2.5)
                                    }
                                }
                                .onTapGesture {
                                    selectedColorIndex = index
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Categories") {
                    ForEach(BaseCategory.allCases) { category in
                        HStack {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(Theme.colorForCategory(category.rawValue))
                                .frame(width: 24)
                            Text(category.rawValue)
                        }
                    }
                    ForEach(customCategories) { category in
                        HStack {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.gray)
                                .frame(width: 24)
                            Text(category.name)
                            Spacer()
                            Button {
                                customCategories.removeAll { $0.id == category.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    HStack {
                        TextField("Add custom category", text: $customCategoryName)
                        Button {
                            let trimmed = customCategoryName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            customCategories.append(ExpenseCategory(customName: trimmed))
                            customCategoryName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.accentTeal)
                        }
                        .disabled(customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTrip()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveTrip() {
        let allCategories = BaseCategory.allCases.map { ExpenseCategory(base: $0) } + customCategories
        let trip = Trip(
            name: name.trimmingCharacters(in: .whitespaces),
            budget: budgetValue,
            currency: currencyCode,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            colorHex: Theme.bubblePalette[selectedColorIndex],
            categories: allCategories
        )
        modelContext.insert(trip)
        dismiss()
    }
}

#Preview {
    AddTripSheet()
        .modelContainer(SampleData.container)
}
