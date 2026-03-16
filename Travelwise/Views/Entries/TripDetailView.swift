import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddExpense = false
    @State private var showingMoveToPast = false
    @State private var showingDeleteTrip = false
    @State private var showingEditTrip = false

    private var budgetProgress: Double {
        guard trip.budget > 0 else { return 0 }
        return min(trip.totalSpent / trip.budget, 1.0)
    }

    private var expensesByCategory: [(category: String, expenses: [Expense], total: Double, limit: Double?)] {
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, expenses.sorted { $0.createdAt > $1.createdAt }, total, category.budgetLimit)
        }.sorted { $0.total > $1.total }
    }

    var body: some View {
        List {
            budgetOverviewSection
            expensesSection
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if let url = CSVExporter.csvFileURL(for: trip) {
                        ShareLink(item: url, preview: SharePreview("Export \(trip.name)", image: Image(systemName: "doc.text"))) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    Menu {
                        Button {
                            showingEditTrip = true
                        } label: {
                            Label("Edit Trip", systemImage: "pencil")
                        }
                        if !trip.isPast {
                            Button {
                                showingMoveToPast = true
                            } label: {
                                Label("Move to Past Trips", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            }
                        }
                        Button(role: .destructive) {
                            showingDeleteTrip = true
                        } label: {
                            Label("Delete Trip", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Move to Past Trips?", isPresented: $showingMoveToPast) {
            Button("Cancel", role: .cancel) { }
            Button("Move") {
                trip.endDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
                dismiss()
            }
        } message: {
            Text("This will mark \"\(trip.name)\" as a past trip. You can still view it in the Past Trips tab.")
        }
        .alert("Delete Trip?", isPresented: $showingDeleteTrip) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(trip)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \"\(trip.name)\" and all its expenses. This cannot be undone.")
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseSheet(trip: trip)
        }
        .sheet(isPresented: $showingEditTrip) {
            EditTripSheet(trip: trip)
        }
    }

    private var budgetOverviewSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyHelper.format(trip.totalSpent, code: trip.currency))
                            .font(.title2.weight(.bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyHelper.format(trip.budget, code: trip.currency))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: budgetProgress)
                    .tint(budgetProgress > 0.9 ? .red : (budgetProgress > 0.7 ? .orange : Theme.accentTeal))

                HStack {
                    Text("\(Int(trip.budgetUsedPercent))% used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(CurrencyHelper.format(max(0, trip.budget - trip.totalSpent), code: trip.currency)) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var expensesSection: some View {
        if expensesByCategory.isEmpty {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        } else {
            ForEach(expensesByCategory, id: \.category) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        NavigationLink {
                            ExpenseDetailView(expense: expense, currencyCode: trip.currency, categories: trip.categories)
                        } label: {
                            ExpenseRowView(expense: expense, currencyCode: trip.currency)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(expense)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    categoryHeader(for: group)
                }
            }
        }
    }

    private func categoryHeader(for group: (category: String, expenses: [Expense], total: Double, limit: Double?)) -> some View {
        HStack {
            let cat = trip.categories.first { $0.name == group.category }
            Image(systemName: cat?.systemImage ?? "tag.fill")
                .foregroundStyle(Theme.colorForCategory(group.category))
            Text(group.category)

            if let limit = group.limit, group.total > limit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
            }

            Spacer()

            if let limit = group.limit {
                Text("\(CurrencyHelper.format(group.total, code: trip.currency)) / \(CurrencyHelper.format(limit, code: trip.currency))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(group.total > limit ? .red : .secondary)
            } else {
                Text(CurrencyHelper.format(group.total, code: trip.currency))
                    .font(.caption.weight(.semibold))
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(name: "Tokyo Adventure", budget: 5000))
    }
    .modelContainer(SampleData.container)
}
