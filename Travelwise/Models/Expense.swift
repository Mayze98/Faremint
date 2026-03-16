import Foundation
import SwiftData

@Model
final class Expense {
    var title: String
    var amount: Double
    var originalAmount: Double
    var splitPercent: Double?
    var categoryName: String
    var note: String

    @Attribute(.externalStorage)
    var photoData: Data?

    var trip: Trip?
    var createdAt: Date

    init(
        title: String,
        amount: Double,
        originalAmount: Double? = nil,
        splitPercent: Double? = nil,
        categoryName: String,
        note: String = "",
        photoData: Data? = nil,
        trip: Trip? = nil
    ) {
        self.title = title
        self.originalAmount = originalAmount ?? amount
        self.splitPercent = splitPercent
        self.categoryName = categoryName
        self.note = note
        self.photoData = photoData
        self.trip = trip
        self.createdAt = .now

        if let percent = splitPercent {
            self.amount = (originalAmount ?? amount) * (percent / 100.0)
        } else {
            self.amount = amount
        }
    }
}
