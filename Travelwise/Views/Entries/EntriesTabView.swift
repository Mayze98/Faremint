import SwiftUI
import SwiftData
import FirebaseAuth

struct EntriesTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel = EntriesViewModel()
    @State private var showingPastTrips = false
    @State private var showingProUpgrade = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Trips")
                            .font(.largeTitle.weight(.bold))
                        Text("Your \(Calendar.current.component(.year, from: .now), format: .number.grouping(.never)) adventures")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            if storeKitService.canAddTrip(currentTripCount: allTrips.count) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    viewModel.showingAddTrip = true
                                }
                            } else {
                                showingProUpgrade = true
                            }
                        } label: {
                            Image(systemName: "airplane.departure")
                                .font(.title3)
                                .foregroundStyle(Theme.accentTeal)
                                .frame(width: 40, height: 40)
                                .background(Theme.accentTeal.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button {
                            showingPastTrips = true
                        } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
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

                if viewModel.trips(from: allTrips).isEmpty {
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
                } else if let current = viewModel.currentTrip(from: allTrips) {
                    // Trip selector chips + edit button
                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.trips(from: allTrips)) { trip in
                                    Button {
                                        viewModel.selectTrip(trip)
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
                                            viewModel.isSelected(trip, allTrips: allTrips)
                                                ? Color(hex: trip.colorHex).opacity(0.15)
                                                : Color(.systemGray6)
                                        )
                                        .foregroundStyle(
                                            viewModel.isSelected(trip, allTrips: allTrips)
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
                            viewModel.showingEditTrip = true
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
            .onChange(of: authService.currentUser?.uid) { _, _ in
                viewModel.reset()
            }
            .onChange(of: allTrips) { _, trips in
                warmUpRates(for: trips)
            }
            .onAppear {
                warmUpRates(for: allTrips)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    // If tapping FAB would open the add trip flow, check limit first
                    let activeTrips = viewModel.trips(from: allTrips)
                    if activeTrips.isEmpty && !storeKitService.canAddTrip(currentTripCount: allTrips.count) {
                        showingProUpgrade = true
                    } else {
                        viewModel.handleFABTap(allTrips: allTrips)
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
                if viewModel.showingAddTrip {
                    AddTripFlowView(isPresented: $viewModel.showingAddTrip)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .sheet(isPresented: $viewModel.showingAddExpense) {
                if let current = viewModel.currentTrip(from: allTrips) {
                    AddExpenseSheet(trip: current)
                }
            }
            .sheet(isPresented: $viewModel.showingEditTrip) {
                if let current = viewModel.currentTrip(from: allTrips) {
                    EditTripSheet(trip: current)
                }
            }
            .sheet(isPresented: $showingPastTrips) {
                PastTripsTabView()
            }
            .sheet(isPresented: $showingProUpgrade) {
                ProUpgradeView()
            }
        }
    }

    private func warmUpRates(for trips: [Trip]) {
        let homeCurrency = UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
        let uniqueCurrencies = Set(trips.map(\.currency))
        for currency in uniqueCurrencies where currency != homeCurrency {
            ExchangeRateService.shared.warmUp(from: currency, to: homeCurrency)
        }
    }
}

#Preview {
    EntriesTabView()
        .modelContainer(SampleData.container)
        .environment(FirestoreService())
}
