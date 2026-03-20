import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestoreService

    @State private var viewModel: ExpenseFormViewModel

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
                }

                Section("Notes") {
                    TextField("Add a note (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                PhotoPickerSection(imageData: $viewModel.photoData)
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveNewExpense(trip: trip, modelContext: modelContext, firestoreService: firestoreService)
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
            ForEach(trip.categories) { category in
                Button {
                    viewModel.selectedCategory = category.name
                } label: {
                    VStack(spacing: 6) {
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

                        Text(category.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(
                                viewModel.selectedCategory == category.name ? .primary : .secondary
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
}
