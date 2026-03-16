import SwiftUI
import SwiftData

struct PastTripsTabView: View {
    @Query(sort: \Trip.endDate, order: .reverse) private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext

    private var pastTrips: [Trip] {
        allTrips.filter { $0.isPast }
    }

    var body: some View {
        NavigationStack {
            List {
                if pastTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(pastTrips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            PastTripRow(trip: trip)
                        }
                        .tint(.primary)
                    }
                    .onDelete(perform: deleteTrips)
                }
            }
            .navigationTitle("Past Trips")
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
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(pastTrips[index])
        }
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
}
