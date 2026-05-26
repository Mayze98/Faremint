import SwiftUI
import SwiftData
import StoreKit

struct AddExpenseSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestoreService

    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel: ExpenseFormViewModel
    @State private var showingNewCategorySheet = false
    @State private var isEditingCategories = false
    @State private var showingProUpgrade = false
    @State private var isSaving = false
    @AppStorage("totalExpensesSaved") private var totalExpensesSaved = 0
    @Environment(\.requestReview) private var requestReview

    init(trip: Trip) {
        self.trip = trip
        _viewModel = State(initialValue: ExpenseFormViewModel(trip: trip))
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

                if storeKitService.isProUser {
                    LocationPickerSection(
                        locationName: $viewModel.locationName,
                        latitude: $viewModel.latitude,
                        longitude: $viewModel.longitude
                    )
                } else {
                    Section {
                        Button { showingProUpgrade = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                Text("Add location")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                proBadge
                            }
                        }
                    } header: {
                        Text("Location")
                    }
                }

                if storeKitService.isProUser {
                    PhotoPickerSection(imageData: $viewModel.photoData)
                } else {
                    Section {
                        Button { showingProUpgrade = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                Text("Add photo")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                proBadge
                            }
                        }
                    } header: {
                        Text("Picture")
                    }
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSaving = true
                        Task {
                            await viewModel.saveNewExpense(trip: trip, modelContext: modelContext, firestoreService: firestoreService)
                            totalExpensesSaved += 1
                            if totalExpensesSaved == 10 || (totalExpensesSaved > 10 && totalExpensesSaved % 50 == 0) {
                                requestReview()
                            }
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.canSave || isSaving)
                }
            }
            .task {
                await viewModel.fetchExchangeRate()
            }
            .sheet(isPresented: $showingProUpgrade) { ProUpgradeView() }
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.accentTeal, in: Capsule())
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
            ForEach(trip.categories) { category in
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
            NewCategorySheet(existingCategories: trip.categories) { category in
                addCategory(category)
            }
        }
    }

    private func addCategory(_ category: ExpenseCategory) {
        let exists = trip.categories.contains {
            $0.name.localizedCaseInsensitiveCompare(category.name) == .orderedSame
        }
        guard !exists else { return }
        trip.categories.append(category)
        trip.updatedAt = .now
        firestoreService.saveTrip(trip)
        viewModel.selectedCategory = category.name
    }

    private func removeCategory(_ category: ExpenseCategory) {
        trip.categories.removeAll { $0.id == category.id }
        trip.updatedAt = .now
        firestoreService.saveTrip(trip)
        if viewModel.selectedCategory == category.name {
            viewModel.selectedCategory = trip.categories.first?.name ?? BaseCategory.foodAndDrinks.rawValue
        }
        if trip.categories.isEmpty {
            isEditingCategories = false
        }
    }
}

#Preview {
    let trip: Trip = {
        let t = Trip(name: "Test", budget: 1000)
        SampleData.container.mainContext.insert(t)
        return t
    }()
    AddExpenseSheet(trip: trip)
        .modelContainer(SampleData.container)
        .environment(FirestoreService())
        .environment(StoreKitService())
}
