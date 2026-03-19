import SwiftUI
import SwiftData

@Observable
final class PastTripsViewModel {

    func pastTrips(from allTrips: [Trip]) -> [Trip] {
        allTrips.filter { $0.isPast }
    }

    func tripsByYear(from allTrips: [Trip]) -> [(year: Int, trips: [Trip])] {
        let calendar = Calendar.current
        let past = pastTrips(from: allTrips)
        let grouped = Dictionary(grouping: past) { trip in
            calendar.component(.year, from: trip.startDate)
        }
        return grouped
            .map { (year: $0.key, trips: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.year > $1.year }
    }

    func deleteTrip(_ trip: Trip, modelContext: ModelContext) {
        modelContext.delete(trip)
    }
}
