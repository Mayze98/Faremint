import SwiftUI
import SwiftData

struct EntriesTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTrip = false
    @State private var showingAddExpense = false
    @State private var showingEditTrip = false
    @State private var showingBubbles = false
    @State private var displayedTrip: Trip?

    private var trips: [Trip] {
        allTrips.filter { !$0.isPast }
    }

    private var currentYearTrips: [Trip] {
        let year = Calendar.current.component(.year, from: .now)
        return trips.filter { Calendar.current.component(.year, from: $0.startDate) == year }
    }

    private var latestTrip: Trip? {
        trips.first
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Trips")
                            .font(.largeTitle.weight(.bold))
                        Text("Track your travel expenses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !trips.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingBubbles.toggle()
                            }
                        } label: {
                            Image(systemName: showingBubbles ? "list.bullet" : "circle.grid.3x3.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accentTeal)
                                .frame(width: 40, height: 40)
                                .background(Theme.accentTeal.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                if trips.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No trips yet")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Tap + to create your first trip")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else if showingBubbles {
                    BubbleClusterView(trips: currentYearTrips) { trip in
                        displayedTrip = trip
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingBubbles = false
                        }
                    }
                    .padding()
                } else if let current = displayedTrip ?? latestTrip {
                    // Trip selector chips + edit button
                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(trips) { trip in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            displayedTrip = trip
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(hex: trip.colorHex))
                                                .frame(width: 10, height: 10)
                                            Text(trip.name)
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            (displayedTrip ?? latestTrip)?.persistentModelID == trip.persistentModelID
                                                ? Color(hex: trip.colorHex).opacity(0.15)
                                                : Color(.systemGray6)
                                        )
                                        .foregroundStyle(
                                            (displayedTrip ?? latestTrip)?.persistentModelID == trip.persistentModelID
                                                ? Color(hex: trip.colorHex)
                                                : .secondary
                                        )
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.leading)
                            .padding(.vertical, 12)
                        }

                        Button {
                            showingEditTrip = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accentTeal)
                        }
                        .padding(.horizontal, 12)
                    }

                    // Inline trip detail
                    TripDetailInlineView(trip: current)
                }
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if showingBubbles || trips.isEmpty {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showingAddTrip = true
                        }
                    } else {
                        showingAddExpense = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.accentTeal, in: Circle())
                        .shadow(color: Theme.accentTeal.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .overlay {
                if showingAddTrip {
                    AddTripFlowView(isPresented: $showingAddTrip)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                if let current = displayedTrip ?? latestTrip {
                    AddExpenseSheet(trip: current)
                }
            }
            .sheet(isPresented: $showingEditTrip) {
                if let current = displayedTrip ?? latestTrip {
                    EditTripSheet(trip: current)
                }
            }
        }
    }
}

/// Inline version of trip detail shown directly in the entries tab
struct TripDetailInlineView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false

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
            // Budget overview
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

            // Expenses
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
                        }
                    } header: {
                        categoryHeader(for: group)
                    }
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
    EntriesTabView()
        .modelContainer(SampleData.container)
}
