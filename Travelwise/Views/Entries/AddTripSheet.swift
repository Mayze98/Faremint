import SwiftUI
import SwiftData

struct AddTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var budget = ""
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now.addingTimeInterval(7 * 24 * 3600)
    @State private var selectedColorIndex = 0
    @State private var customCategories: [ExpenseCategory] = []
    @State private var showingNewCategorySheet = false
    @State private var categoryLimits: [String: String] = [:]
    @State private var isSaving = false

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
                    Button {
                        showingNewCategorySheet = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accentTeal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingNewCategorySheet) {
                        let existing = BaseCategory.allCases.map { ExpenseCategory(base: $0) } + customCategories
                        NewCategorySheet(existingCategories: existing) { category in
                            customCategories.append(category)
                        }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if totalCategoryLimits > 0 {
                            HStack {
                                Text("Allocated: \(CurrencyHelper.format(totalCategoryLimits, code: currencyCode))")
                                Text("of")
                                Text(CurrencyHelper.format(budgetValue, code: currencyCode))
                            }
                            .font(.caption)

                            if remainingBudget > 0 {
                                Text("\(CurrencyHelper.format(remainingBudget, code: currencyCode)) unallocated")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if remainingBudget < 0 {
                                Text("Over budget by \(CurrencyHelper.format(-remainingBudget, code: currencyCode))")
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
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        saveTrip()
                    }
                    .disabled(!canSave || isSaving)
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

    private func saveTrip() {
        let baseCategories = BaseCategory.allCases.map {
            ExpenseCategory(base: $0, budgetLimit: limitValue(for: $0.rawValue))
        }
        let customWithLimits = customCategories.map {
            ExpenseCategory(customName: $0.name, systemImage: $0.systemImage, budgetLimit: limitValue(for: $0.name))
        }
        let allCategories = baseCategories + customWithLimits
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
