import SwiftUI
import SwiftData

struct AddTripFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FirestoreService.self) private var firestoreService
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @Binding var isPresented: Bool

    @State private var viewModel: AddTripFlowViewModel
    @State private var showingCurrencyPicker = false
    @State private var showingNewCategorySheet = false
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var isSaving = false

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _viewModel = State(initialValue: AddTripFlowViewModel(
            currencyCode: UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
        ))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // Back button (or hidden placeholder on step 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            _ = viewModel.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                    }
                    .opacity(viewModel.step > 0 ? 1 : 0)
                    .disabled(viewModel.step == 0)

                    Spacer()

                    // Step indicator
                    HStack(spacing: 6) {
                        ForEach(0..<5) { i in
                            Capsule()
                                .fill(i <= viewModel.step ? Theme.accentTeal : Color(.systemGray4))
                                .frame(width: i == viewModel.step ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.step)
                        }
                    }

                    Spacer()

                    // Close button — always visible
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Step content
                Group {
                    switch viewModel.step {
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
                        stepMustSpendView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 3:
                        stepPrioritiesView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 4:
                        stepReviewView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.step)

                Spacer()

                // Bottom button
                Button {
                    handleNext()
                } label: {
                    Text(viewModel.step == 4 ? "Create Trip" : "Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(viewModel.nextButtonEnabled ? Theme.accentTeal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.nextButtonEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingNewCategorySheet) {
            let allCategories = BaseCategory.allCases.map { ExpenseCategory(base: $0) } + viewModel.customCategories
            NewCategorySheet(existingCategories: allCategories) { newCategory in
                viewModel.customCategories.append(newCategory)
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

            TextField("e.g. Tokyo, Bali, Paris", text: $viewModel.name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)
                .onChange(of: viewModel.name) { _, newName in
                    viewModel.inferCurrency(from: newName)
                }

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
                                if index == viewModel.selectedColorIndex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                    Circle()
                                        .strokeBorder(Color(hex: hex).opacity(0.5), lineWidth: 1, antialiased: true)
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .onTapGesture {
                                viewModel.selectedColorIndex = index
                            }
                    }
                }
            }

            // Date pickers
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showingStartDatePicker = true
                        } label: {
                            Text(viewModel.startDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 22)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("End")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showingEndDatePicker = true
                        } label: {
                            Text(viewModel.endDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Text("\(tripLengthDays) \(tripLengthDays == 1 ? "day" : "days")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .onChange(of: viewModel.startDate) { _, _ in
                viewModel.ensureEndDateAfterStart()
                // Automatically open end date picker after start date is selected
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingEndDatePicker = true
                }
            }
            .sheet(isPresented: $showingStartDatePicker) {
                DatePickerSheet(title: "Start Date", selection: $viewModel.startDate, minimumDate: nil)
            }
            .sheet(isPresented: $showingEndDatePicker) {
                DatePickerSheet(title: "End Date", selection: $viewModel.endDate, minimumDate: viewModel.startDate)
            }
        }
        .padding(.horizontal)
    }

    private var tripLengthDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: viewModel.startDate)
        let end = calendar.startOfDay(for: viewModel.endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }

    private var stepBudgetView: some View {
        VStack(spacing: 24) {
            Image(systemName: "banknote")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            Text("What is your budget?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(viewModel.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Budget input — always in home currency
            VStack(spacing: 6) {
                // Clear label so the user knows this is their home currency
                HStack(spacing: 4) {
                    Image(systemName: "house")
                        .font(.caption2)
                    Text("Budget in \(viewModel.homeCurrency)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(.systemGray6), in: Capsule())

                HStack(spacing: 2) {
                    Text(viewModel.homeCurrencySymbol)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $viewModel.budget)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity)

            // Trip currency selector
            VStack(spacing: 8) {
                Text("Trip currency")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingCurrencyPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.tripCurrency)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accentTeal.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.accentTeal)
                }
                .sheet(isPresented: $showingCurrencyPicker) {
                    TripCurrencyPickerSheet(selectedCurrency: $viewModel.tripCurrency)
                }
            }

            // Equivalent in trip currency
            if viewModel.tripCurrency != viewModel.homeCurrency {
                Group {
                    if viewModel.rateError {
                        Text("Could not fetch exchange rate")
                            .foregroundStyle(.red)
                    } else if viewModel.isFetchingRate {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Fetching rate…")
                        }
                        .foregroundStyle(.secondary)
                    } else if !viewModel.budgetInTripCurrency.isEmpty {
                        Text("≈ \(viewModel.budgetInTripCurrency) \(viewModel.tripCurrency)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .animation(.easeInOut, value: viewModel.budgetInTripCurrency)
            }
        }
        .padding(.horizontal)
        .task(id: viewModel.tripCurrency) {
            await viewModel.fetchExchangeRate()
        }
    }

    private var stepMustSpendView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            VStack(spacing: 4) {
                Text("Must-spend items")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Add fixed costs like flights or hotels before setting priorities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !viewModel.mustSpendItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.mustSpendItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.category.systemImage)
                                .foregroundStyle(Theme.accentTeal)
                                .frame(width: 28)
                            Text(item.category.rawValue)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: viewModel.mustSpendAmountBinding(for: item))
                                .keyboardType(.decimalPad)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Button {
                                viewModel.removeMustSpendItem(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        if item.id != viewModel.mustSpendItems.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 8)
            }

            HStack(spacing: 10) {
                Picker("Category", selection: $viewModel.mustSpendCategory) {
                    ForEach(BaseCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Amount", text: $viewModel.mustSpendAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button {
                    viewModel.addMustSpendItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accentTeal)
                        .font(.title3)
                }
                .disabled(Double(viewModel.mustSpendAmount) == nil || Double(viewModel.mustSpendAmount) == 0)
            }
            .padding(.horizontal, 24)

            if viewModel.mustSpendTotal > 0 {
                Text("Total reserved: \(CurrencyHelper.format(viewModel.mustSpendTotal, code: viewModel.homeCurrency))")
                    .font(.caption)
                    .foregroundColor(viewModel.isMustSpendWithinBudget ? .secondary : .red)
            }

            if !viewModel.isMustSpendWithinBudget {
                Text("Must-spend items can’t exceed your total budget.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }

    private var stepPrioritiesView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            VStack(spacing: 4) {
                Text("Any spending priorities?")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(viewModel.priorityCategories.isEmpty
                     ? "Optional — select up to 3 categories"
                     : "\(viewModel.priorityCategories.count) of 3 selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: viewModel.priorityCategories.count)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 10)],
                spacing: 10
            ) {
                ForEach(BaseCategory.allCases) { category in
                    let name = category.rawValue
                    let isSelected = viewModel.priorityCategories.contains(name)
                    let isExcluded = viewModel.mustSpendExclusionCategories.contains(name)
                    let isDisabled = isExcluded || (!isSelected && viewModel.priorityCategories.count >= 3)

                    Button {
                        if isSelected {
                            viewModel.priorityCategories.remove(name)
                        } else {
                            viewModel.priorityCategories.insert(name)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemImage)
                                .font(.caption.weight(.semibold))
                            Text(name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected
                                ? Theme.accentTeal.opacity(0.15)
                                : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isSelected ? Theme.accentTeal : Color(.systemGray4),
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        )
                        .foregroundStyle(
                            isDisabled
                                ? Color(.systemGray3)
                                : (isSelected ? Theme.accentTeal : .primary)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
            .padding(.horizontal, 24)

            Text("Priority categories receive a larger slice of your budget.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal)
    }

    private var stepReviewView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Review your budget")
                    .font(.title2.weight(.bold))

                Text("\(CurrencyHelper.format(viewModel.budgetValue, code: viewModel.homeCurrency)) for \(viewModel.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.mustSpendItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Must-spend items")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.mustSpendItems) { item in
                        HStack {
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyHelper.format(Double(item.amount) ?? 0, code: viewModel.homeCurrency))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            // Allocation summary
            allocationSummary
                .padding(.horizontal, 4)

            HStack {
                Text("Category Limits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear All") {
                    viewModel.clearAllLimits()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(BaseCategory.allCases) { category in
                        categoryRow(name: category.rawValue, icon: category.systemImage, color: Theme.colorForCategory(category.rawValue))
                        Divider().padding(.leading, 44)
                    }

                    ForEach(viewModel.customCategories) { category in
                        HStack(spacing: 12) {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.gray)
                                .frame(width: 28)
                            Text(category.name)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: viewModel.categoryLimitBinding(for: category.name))
                                .keyboardType(.decimalPad)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Button {
                                viewModel.removeCustomCategory(category)
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
                    Button {
                        showingNewCategorySheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(Theme.accentTeal)
                                .frame(width: 28)
                            Text("Add custom category")
                                .font(.subheadline)
                                .foregroundStyle(Theme.accentTeal)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.accentTeal)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
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
            TextField("0", text: viewModel.categoryLimitBinding(for: name))
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
            ProgressView(value: min(viewModel.totalCategoryLimits / max(viewModel.budgetValue, 1), 1.0))
                .tint(viewModel.remainingBudget < 0 ? .red : (viewModel.remainingBudget == 0 ? Theme.accentTeal : .orange))

            HStack {
                Text("Allocated: \(CurrencyHelper.format(viewModel.totalCategoryLimits, code: viewModel.homeCurrency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.remainingBudget > 0 {
                    Text("\(CurrencyHelper.format(viewModel.remainingBudget, code: viewModel.homeCurrency)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.remainingBudget < 0 {
                    Text("Over by \(CurrencyHelper.format(-viewModel.remainingBudget, code: viewModel.homeCurrency))")
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

    private func handleNext() {
        withAnimation(.easeInOut(duration: 0.35)) {
            if viewModel.handleNext() {
                guard !isSaving else { return }
                isSaving = true
                viewModel.saveTrip(modelContext: modelContext, firestoreService: firestoreService)
                isPresented = false
            }
        }
    }
}

// MARK: - Trip Currency Picker Sheet

private struct TripCurrencyPickerSheet: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [(code: String, name: String)] {
        if searchText.isEmpty { return CurrencyHelper.commonCurrencies }
        return CurrencyHelper.commonCurrencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.code) { currency in
                    Button {
                        selectedCurrency = currency.code
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(currency.code)
                                    .font(.subheadline.weight(.semibold))
                                Text(currency.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedCurrency == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accentTeal)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search currencies")
            .navigationTitle("Trip Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet

private struct DatePickerSheet: View {
    let title: String
    @Binding var selection: Date
    let minimumDate: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let minimumDate {
                    DatePicker(
                        "",
                        selection: $selection,
                        in: minimumDate...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .tint(Theme.accentTeal)
                    .padding(.horizontal)
                } else {
                    DatePicker(
                        "",
                        selection: $selection,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .tint(Theme.accentTeal)
                    .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accentTeal)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var showing = true
    AddTripFlowView(isPresented: $showing)
        .modelContainer(SampleData.container)
        .environment(FirestoreService())
}
