import Foundation
import SwiftData

@Model
final class Expense {
    /// Stable ID used to match this record with its Firestore document.
    var firestoreID: String
    var title: String
    var amount: Double
    var originalAmount: Double
    var splitPercent: Double?
    var categoryName: String
    var note: String

    @Attribute(.externalStorage)
    var photoData: Data?

    /// Download URL of the photo in Firebase Storage, if uploaded.
    var photoURL: String?

    /// Optional location data attached to this expense.
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    var trip: Trip?
    var createdAt: Date
    /// Timestamp of the last write so the sync merge can resolve conflicts.
    var updatedAt: Date

    init(
        firestoreID: String = UUID().uuidString,
        title: String,
        amount: Double,
        originalAmount: Double? = nil,
        splitPercent: Double? = nil,
        categoryName: String,
        note: String = "",
        photoData: Data? = nil,
        photoURL: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        trip: Trip? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.firestoreID = firestoreID
        self.title = title
        self.originalAmount = originalAmount ?? amount
        self.splitPercent = splitPercent
        self.categoryName = categoryName
        self.note = note
        self.photoData = photoData
        self.photoURL = photoURL
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.trip = trip
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        if let percent = splitPercent {
            self.amount = (originalAmount ?? amount) * (percent / 100.0)
        } else {
            self.amount = amount
        }
    }
}
