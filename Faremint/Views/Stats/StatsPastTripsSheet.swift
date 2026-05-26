import SwiftUI
import SwiftData

// MARK: - StatsPastTripsSheet
//
// A sheet that lists all past trips grouped by year.
// Tapping a trip navigates to PastTripStatsView for that trip.

struct StatsPastTripsSheet: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var allTrips: [Trip]
    @Environment(\.dismiss) private var dismiss

    /// Past trips grouped by year, most recent year first.
    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let past = allTrips.filter { $0.isPast }
        let grouped = Dictionary(grouping: past) {
            Calendar.current.component(.year, from: $0.startDate)
        }
        return grouped
            .map { (year: $0.key, trips: $0.value) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tripsByYear.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(tripsByYear, id: \.year) { section in
                            Section(String(section.year)) {
                                ForEach(section.trips) { trip in
                                    NavigationLink {
                                        PastTripStatsView(trip: trip)
                                    } label: {
                                        tripRow(trip)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Past Trip Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Trip row

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: trip.colorHex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.subheadline.weight(.medium))
                if let endDate = trip.endDate {
                    Text("\(trip.startDate, format: .dateTime.month(.abbreviated).day()) – \(endDate, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(trip.startDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(CurrencyHelper.format(trip.totalSpent, code: UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No past trips")
                .font(.headline)
            Text("Completed trips will appear here grouped by year.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StatsPastTripsSheet()
        .modelContainer(SampleData.container)
}
