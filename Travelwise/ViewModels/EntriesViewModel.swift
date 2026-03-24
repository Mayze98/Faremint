import SwiftUI
import SwiftData

@Observable
final class EntriesViewModel {
    var showingAddTrip = false
    var showingAddExpense = false
    var showingEditTrip = false
    var displayedTrip: Trip?

    func trips(from allTrips: [Trip]) -> [Trip] {
        allTrips.filter { !$0.isPast }
    }

    func currentYearTrips(from allTrips: [Trip]) -> [Trip] {
        let year = Calendar.current.component(.year, from: .now)
        return trips(from: allTrips).filter { Calendar.current.component(.year, from: $0.startDate) == year }
    }

    func latestTrip(from allTrips: [Trip]) -> Trip? {
        trips(from: allTrips).first
    }

    func currentTrip(from allTrips: [Trip]) -> Trip? {
        displayedTrip ?? latestTrip(from: allTrips)
    }

    func isSelected(_ trip: Trip, allTrips: [Trip]) -> Bool {
        currentTrip(from: allTrips)?.persistentModelID == trip.persistentModelID
    }

    func selectTrip(_ trip: Trip) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedTrip = trip
        }
    }

    func handleFABTap(allTrips: [Trip]) {
        let activeTrips = trips(from: allTrips)
        if activeTrips.isEmpty {
            withAnimation(.easeInOut(duration: 0.35)) {
                showingAddTrip = true
            }
        } else {
            showingAddExpense = true
        }
    }
}
