import SwiftUI
import SwiftData

struct EntriesTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTrip = false
    @State private var selectedTrip: Trip?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Trips")
                        .font(.largeTitle.weight(.bold))
                    Text("Track your travel expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                } else {
                    // Bubble cluster
                    BubbleClusterView(trips: trips) { trip in
                        selectedTrip = trip
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddTrip = true
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
            .sheet(isPresented: $showingAddTrip) {
                AddTripSheet()
            }
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
        }
    }
}

#Preview {
    EntriesTabView()
        .modelContainer(SampleData.container)
}
