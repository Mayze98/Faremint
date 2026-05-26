import SwiftData
import Foundation

@MainActor
enum SampleData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, Expense.self, configurations: config)

        let tokyo = Trip(name: "Tokyo Adventure", budget: 5000, colorHex: "45B7D1")
        let paris = Trip(name: "Paris Getaway", budget: 4000, colorHex: "FF6B6B")
        let london = Trip(name: "London Trip", budget: 2000, colorHex: "96CEB4")
        let bali = Trip(name: "Bali Retreat", budget: 6000, colorHex: "4ECDC4")
        let nyc = Trip(name: "NYC Weekend", budget: 3000, colorHex: "FFEAA7")

        for trip in [tokyo, paris, london, bali, nyc] {
            container.mainContext.insert(trip)
        }

        let expenses: [(Trip, String, Double, String)] = [
            (tokyo, "Sushi dinner", 85, "Food & Drinks"),
            (tokyo, "Shinkansen ticket", 200, "Transportation"),
            (tokyo, "Senso-ji temple", 15, "Sightseeing"),
            (tokyo, "Flight to Tokyo", 1200, "Flight"),
            (tokyo, "Hotel Shinjuku", 2000, "Hotels"),
            (paris, "Croissants", 12, "Food & Drinks"),
            (paris, "Metro pass", 50, "Transportation"),
            (paris, "Louvre Museum", 35, "Sightseeing"),
            (paris, "Flight to Paris", 900, "Flight"),
            (paris, "Hotel Marais", 1800, "Hotels"),
            (london, "Fish & Chips", 25, "Food & Drinks"),
            (london, "Oyster card", 60, "Transportation"),
            (london, "Tower of London", 40, "Sightseeing"),
            (london, "Flight to London", 400, "Flight"),
            (london, "Hostel Camden", 375, "Hotels"),
            (bali, "Nasi Goreng", 8, "Food & Drinks"),
            (bali, "Scooter rental", 30, "Transportation"),
            (bali, "Rice terrace tour", 25, "Sightseeing"),
            (bali, "Flight to Bali", 600, "Flight"),
            (bali, "Villa Ubud", 3500, "Hotels"),
            (nyc, "Pizza slice", 5, "Food & Drinks"),
            (nyc, "Subway pass", 33, "Transportation"),
            (nyc, "Statue of Liberty", 24, "Sightseeing"),
            (nyc, "Flight to NYC", 350, "Flight"),
            (nyc, "Hotel Manhattan", 800, "Hotels"),
        ]

        for (trip, title, amount, category) in expenses {
            let expense = Expense(
                title: title,
                amount: amount,
                categoryName: category,
                trip: trip
            )
            container.mainContext.insert(expense)
        }

        return container
    }()
}
