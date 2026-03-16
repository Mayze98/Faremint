import SwiftUI
import SwiftData

struct EditTripSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var budget: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var selectedColorIndex: Int
    @State private var customCategoryName = ""
    @State private var customCategories: [ExpenseCategory]
    @State private var categoryLimits: [String: String]

    init(trip: Trip) {
        self.trip = trip
        _name = State(initialValue: trip.name)
        _budget = State(initialValue: String(trip.budget))
        _startDate = State(initialValue: trip.startDate)
        _hasEndDate = State(initialValue: trip.endDate != nil)
        _endDate = State(initialValue: trip.endDate ?? trip.startDate.addingTimeInterval(7 * 24 * 3600))
        _selectedColorIndex = State(initialValue: Theme.bubblePalette.firstIndex(of: trip.colorHex) ?? 0)
        _customCategories = State(initialValue: trip.categories.filter { $0.isCustom })

        var limits: [String: String] = [:]
        for cat in trip.categories {
            if let limit = cat.budgetLimit {
                limits[cat.name] = String(limit)
            }
        }
        _categoryLimits = State(initialValue: limits)
    }

    private var budgetValue: Double {
        Double(budget) ?? 0
    }

    private var totalCategoryLimits: Double {
        categoryLimits.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var remainingBudget: Double {
        budgetValue - totalCategoryLimits
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && budgetValue > 0 && remainingBudget >= 0
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

                categoriesSection
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach(BaseCategory.allCases) { category in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(Theme.colorForCategory(category.rawValue))
                            .frame(width: 24)
                        Text(category.rawValue)
                        Spacer()
                    }
                    HStack {
                        Text("Limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("No limit", text: categoryLimitBinding(for: category.rawValue))
                            .keyboardType(.decimalPad)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            ForEach(customCategories) { category in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        Text(category.name)
                        Spacer()
                        Button {
                            categoryLimits.removeValue(forKey: category.name)
                            customCategories.removeAll { $0.id == category.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    HStack {
                        Text("Limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("No limit", text: categoryLimitBinding(for: category.name))
                            .keyboardType(.decimalPad)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
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
        } header: {
            Text("Categories")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if totalCategoryLimits > 0 {
                    HStack {
                        Text("Allocated: \(CurrencyHelper.format(totalCategoryLimits, code: trip.currency))")
                        Text("of")
                        Text(CurrencyHelper.format(budgetValue, code: trip.currency))
                    }
                    .font(.caption)

                    if remainingBudget > 0 {
                        Text("\(CurrencyHelper.format(remainingBudget, code: trip.currency)) unallocated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if remainingBudget < 0 {
                        Text("Over budget by \(CurrencyHelper.format(-remainingBudget, code: trip.currency))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Fully allocated")
                            .font(.caption)
                            .foregroundStyle(Theme.accentTeal)
                    }
                } else {
                    Text("Set an optional spending limit per category. Limits should add up to your total budget.")
                }
            }
        }
    }

    private func categoryLimitBinding(for name: String) -> Binding<String> {
        Binding(
            get: { categoryLimits[name, default: ""] },
            set: { categoryLimits[name] = $0 }
        )
    }

    private func limitValue(for name: String) -> Double? {
        guard let text = categoryLimits[name], let value = Double(text), value > 0 else { return nil }
        return value
    }

    private func applyChanges() {
        trip.name = name.trimmingCharacters(in: .whitespaces)
        trip.budget = budgetValue
        trip.startDate = startDate
        trip.endDate = hasEndDate ? endDate : nil
        trip.colorHex = Theme.bubblePalette[selectedColorIndex]

        let baseCategories = BaseCategory.allCases.map {
            ExpenseCategory(base: $0, budgetLimit: limitValue(for: $0.rawValue))
        }
        let customWithLimits = customCategories.map {
            ExpenseCategory(customName: $0.name, systemImage: $0.systemImage, budgetLimit: limitValue(for: $0.name))
        }
        trip.categories = baseCategories + customWithLimits
        dismiss()
    }
}

#Preview {
    EditTripSheet(trip: Trip(name: "Tokyo Adventure", budget: 5000))
        .modelContainer(SampleData.container)
}
