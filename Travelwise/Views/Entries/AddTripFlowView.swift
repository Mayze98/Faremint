import SwiftUI
import SwiftData

struct AddTripFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode = "CAD"

    // Flow state
    @State private var step = 0

    // Step 1: Name
    @State private var name = ""

    // Step 2: Budget
    @State private var budget = ""

    // Step 3: Category limits (auto-filled then editable)
    @State private var categoryLimits: [String: String] = [:]
    @State private var customCategoryName = ""
    @State private var customCategories: [ExpenseCategory] = []

    // Trip options
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now.addingTimeInterval(7 * 24 * 3600)
    @State private var selectedColorIndex = Int.random(in: 0..<8)

    // Auto-allocation percentages for built-in categories
    private static let allocationPercents: [String: Double] = [
        "Hotels": 0.30,
        "Flight": 0.25,
        "Food & Drinks": 0.20,
        "Sightseeing": 0.10,
        "Transportation": 0.10,
        "Souvenir": 0.05
    ]

    private var budgetValue: Double {
        Double(budget) ?? 0
    }

    private var totalCategoryLimits: Double {
        categoryLimits.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var remainingBudget: Double {
        budgetValue - totalCategoryLimits
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        if step > 0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step -= 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: step > 0 ? "chevron.left" : "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                    }

                    Spacer()

                    // Step indicator
                    HStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(i <= step ? Theme.accentTeal : Color(.systemGray4))
                                .frame(width: i == step ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: step)
                        }
                    }

                    Spacer()

                    // Invisible spacer to balance the back button
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Step content
                Group {
                    switch step {
                    case 0:
                        stepNameView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 1:
                        stepBudgetView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 2:
                        stepReviewView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: step)

                Spacer()

                // Bottom button
                Button {
                    handleNext()
                } label: {
                    Text(step == 2 ? "Create Trip" : "Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(nextButtonEnabled ? Theme.accentTeal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!nextButtonEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Step Views

    private var stepNameView: some View {
        VStack(spacing: 24) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            Text("Where are you going?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            TextField("e.g. Tokyo, Bali, Paris", text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)

            // Color picker
            VStack(spacing: 12) {
                Text("Pick a color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Array(Theme.bubblePalette.enumerated()), id: \.offset) { index, hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if index == selectedColorIndex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                    Circle()
                                        .strokeBorder(Color(hex: hex).opacity(0.5), lineWidth: 1, antialiased: true)
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .onTapGesture {
                                selectedColorIndex = index
                            }
                    }
                }
            }

            // Date pickers
            VStack(spacing: 8) {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    .font(.subheadline)
                Toggle("Set end date", isOn: $hasEndDate)
                    .font(.subheadline)
                if hasEndDate {
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.horizontal)
    }

    private var stepBudgetView: some View {
        VStack(spacing: 24) {
            Image(systemName: "banknote")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            Text("What is your budget?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.secondary)
                TextField("0", text: $budget)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal)
    }

    private var stepReviewView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Review your budget")
                    .font(.title2.weight(.bold))

                Text("\(CurrencyHelper.format(budgetValue, code: currencyCode)) for \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Allocation summary
            allocationSummary
                .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(BaseCategory.allCases) { category in
                        categoryRow(name: category.rawValue, icon: category.systemImage, color: Theme.colorForCategory(category.rawValue))
                        Divider().padding(.leading, 44)
                    }

                    ForEach(customCategories) { category in
                        HStack(spacing: 12) {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.gray)
                                .frame(width: 28)
                            Text(category.name)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: categoryLimitBinding(for: category.name))
                                .keyboardType(.decimalPad)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Button {
                                categoryLimits.removeValue(forKey: category.name)
                                customCategories.removeAll { $0.id == category.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 44)
                    }

                    // Add custom category
                    HStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                        TextField("Add custom category", text: $customCategoryName)
                            .font(.subheadline)
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
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    // MARK: - Components

    private func categoryRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(name)
                .font(.subheadline)
            Spacer()
            TextField("0", text: categoryLimitBinding(for: name))
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var allocationSummary: some View {
        VStack(spacing: 6) {
            ProgressView(value: min(totalCategoryLimits / max(budgetValue, 1), 1.0))
                .tint(remainingBudget < 0 ? .red : (remainingBudget == 0 ? Theme.accentTeal : .orange))

            HStack {
                Text("Allocated: \(CurrencyHelper.format(totalCategoryLimits, code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if remainingBudget > 0 {
                    Text("\(CurrencyHelper.format(remainingBudget, code: currencyCode)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if remainingBudget < 0 {
                    Text("Over by \(CurrencyHelper.format(-remainingBudget, code: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Fully allocated")
                        .font(.caption)
                        .foregroundStyle(Theme.accentTeal)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Logic

    private var currencySymbol: String {
        let locale = Locale.current
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.currencySymbol ?? "$"
    }

    private var nextButtonEnabled: Bool {
        switch step {
        case 0: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: budgetValue > 0
        case 2: remainingBudget >= 0
        default: false
        }
    }

    private func handleNext() {
        switch step {
        case 0:
            withAnimation(.easeInOut(duration: 0.35)) {
                step = 1
            }
        case 1:
            autoAllocateBudget()
            withAnimation(.easeInOut(duration: 0.35)) {
                step = 2
            }
        case 2:
            saveTrip()
        default:
            break
        }
    }

    private func autoAllocateBudget() {
        let budget = budgetValue
        for (categoryName, percent) in Self.allocationPercents {
            let amount = (budget * percent).rounded()
            categoryLimits[categoryName] = String(Int(amount))
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
    AddTripFlowView()
        .modelContainer(SampleData.container)
}
