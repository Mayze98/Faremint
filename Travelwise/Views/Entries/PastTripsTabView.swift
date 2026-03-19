import SwiftUI
import SwiftData

struct PastTripsTabView: View {
    @Query(sort: \Trip.endDate, order: .reverse) private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @Environment(FirestoreService.self) private var firestoreService
    @State private var viewModel = PastTripsViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Past Trips")
                        .font(.largeTitle.weight(.bold))
                    Text("Your completed adventures")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                if viewModel.pastTrips(from: allTrips).isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.tripsByYear(from: allTrips), id: \.year) { group in
                            Section {
                                ForEach(group.trips) { trip in
                                    NavigationLink {
                                        PastTripStatsView(trip: trip)
                                    } label: {
                                        PastTripRow(trip: trip)
                                    }
                                    .tint(.primary)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTrip(trip, modelContext: modelContext, firestoreService: firestoreService)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(String(group.year))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No past trips")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Completed trips will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

}

private struct PastTripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: trip.colorHex))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "airplane")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    if let end = trip.endDate {
                        Text(trip.startDate, format: .dateTime.month(.abbreviated).day())
                        Text("–")
                        Text(end, format: .dateTime.month(.abbreviated).day().year())
                    } else {
                        Text(trip.startDate, format: .dateTime.month(.abbreviated).day().year())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyHelper.format(trip.totalSpent, code: trip.currency))
                    .font(.subheadline.weight(.semibold))
                Text("of \(CurrencyHelper.format(trip.budget, code: trip.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PastTripsTabView()
        .modelContainer(SampleData.container)
        .environment(FirestoreService())
}
