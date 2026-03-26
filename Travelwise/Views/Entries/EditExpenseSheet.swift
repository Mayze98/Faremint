import SwiftUI
import SwiftData

struct EditExpenseSheet: View {
    let expense: Expense
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestoreService

    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel: ExpenseFormViewModel
    @State private var categories: [ExpenseCategory]
    @State private var showingNewCategorySheet = false
    @State private var isEditingCategories = false
    @State private var showingProUpgrade = false

    init(expense: Expense, categories: [ExpenseCategory], currencyCode: String) {
        self.expense = expense
        self.currencyCode = currencyCode
        _viewModel = State(initialValue: ExpenseFormViewModel(expense: expense))
        _categories = State(initialValue: categories)
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection

                Section("Details") {
                    TextField("Expense title", text: $viewModel.title)
                }

                Section("Category") {
                    categoryGrid
                    addCategoryButton
                }

                Section("Notes") {
                    TextField("Add a note (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Show location picker if Pro, or if the expense already has a location (preserve existing data after downgrade)
                if storeKitService.isProUser || viewModel.hasLocation {
                    LocationPickerSection(
                        locationName: $viewModel.locationName,
                        latitude: $viewModel.latitude,
                        longitude: $viewModel.longitude
                    )
                } else {
                    Section("Location") {
                        Button { showingProUpgrade = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accentTeal)
                                Text("Pro feature — Upgrade to tag location")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Show picker if Pro, or if the expense already has a photo (preserve existing data after downgrade)
                if storeKitService.isProUser || viewModel.photoData != nil {
                    PhotoPickerSection(imageData: $viewModel.photoData)
                } else {
                    Section("Picture") {
                        Button { showingProUpgrade = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accentTeal)
                                Text("Pro feature — Upgrade to add photos")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .sheet(isPresented: $showingProUpgrade) { ProUpgradeView() }
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateExpense(firestoreService: firestoreService)
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                await viewModel.fetchExchangeRate()
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                // Currency toggle — only shown when trip currency differs from home currency
                if viewModel.needsConversion {
                    Picker("Currency", selection: $viewModel.inputCurrency) {
                        Text(viewModel.tripCurrency).tag(viewModel.tripCurrency)
                        Text(viewModel.homeCurrency).tag(viewModel.homeCurrency)
                    }
                    .pickerStyle(.segmented)
                }

                // Amount input
                HStack {
                    Text(CurrencyHelper.symbol(for: viewModel.inputCurrency))
                        .foregroundStyle(.secondary)
                        .font(.title2.weight(.semibold))
                    TextField("0.00", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                }

                // Converted preview or loading/error state
                if viewModel.needsConversion {
                    if viewModel.rateError {
                        Text("Could not fetch exchange rate — amount saved as-is")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if !viewModel.convertedPreview.isEmpty {
                        Text(viewModel.convertedPreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if viewModel.exchangeRate == nil {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Fetching exchange rate…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Amount")
        } footer: {
            if viewModel.needsConversion && !viewModel.rateError {
                Text("Saved in \(viewModel.homeCurrency)")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(categories) { category in
                Button {
                    viewModel.selectedCategory = category.name
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topLeading) {
                            Image(systemName: category.systemImage)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(
                                    viewModel.selectedCategory == category.name
                                        ? Theme.colorForCategory(category.name).opacity(0.2)
                                        : Color(.systemGray6)
                                )
                                .foregroundStyle(
                                    viewModel.selectedCategory == category.name
                                        ? Theme.colorForCategory(category.name)
                                        : .secondary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            viewModel.selectedCategory == category.name
                                                ? Theme.colorForCategory(category.name)
                                                : .clear,
                                            lineWidth: 2
                                        )
                                )
                                .rotationEffect(isEditingCategories ? .degrees(-2) : .degrees(0))
                                .animation(
                                    isEditingCategories
                                        ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true)
                                        : .default,
                                    value: isEditingCategories
                                )

                            if isEditingCategories && category.isCustom {
                                Button {
                                    removeCategory(category)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .background(Circle().fill(.background))
                                }
                                .offset(x: -6, y: -6)
                            }
                        }

                        Text(category.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(
                                viewModel.selectedCategory == category.name ? .primary : .secondary
                            )
                    }
                }
                .buttonStyle(.plain)
                .onLongPressGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingCategories = true
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var addCategoryButton: some View {
        Button {
            showingNewCategorySheet = true
        } label: {
            Label("Add Category", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accentTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingNewCategorySheet) {
            NewCategorySheet(existingCategories: categories) { category in
                addCategory(category)
            }
        }
    }

    private func addCategory(_ category: ExpenseCategory) {
        let exists = categories.contains {
            $0.name.localizedCaseInsensitiveCompare(category.name) == .orderedSame
        }
        guard !exists else { return }
        categories.append(category)
        if let trip = expense.trip {
            trip.categories.append(category)
            trip.updatedAt = .now
            firestoreService.saveTrip(trip)
        }
        viewModel.selectedCategory = category.name
    }

    private func removeCategory(_ category: ExpenseCategory) {
        categories.removeAll { $0.id == category.id }
        if let trip = expense.trip {
            trip.categories.removeAll { $0.id == category.id }
            trip.updatedAt = .now
            firestoreService.saveTrip(trip)
        }
        if viewModel.selectedCategory == category.name {
            viewModel.selectedCategory = categories.first?.name ?? BaseCategory.foodAndDrinks.rawValue
        }
        if categories.isEmpty {
            isEditingCategories = false
        }
    }
}
