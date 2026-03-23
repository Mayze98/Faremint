import SwiftUI

enum BaseCategory: String, Codable, CaseIterable, Identifiable {
    case foodAndDrinks = "Food & Drinks"
    case transportation = "Transportation"
    case sightseeing = "Sightseeing"
    case activities = "Activities"
    case flight = "Flight"
    case hotels = "Hotels"
    case shopping = "Shopping"
    case souvenir = "Souvenir"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .foodAndDrinks: "fork.knife"
        case .transportation: "car.fill"
        case .sightseeing: "binoculars.fill"
        case .activities: "figure.walk"
        case .flight: "airplane"
        case .hotels: "bed.double.fill"
        case .shopping: "bag.fill"
        case .souvenir: "gift.fill"
        }
    }
}

struct ExpenseCategory: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let systemImage: String
    let isCustom: Bool
    var budgetLimit: Double?

    init(base: BaseCategory, budgetLimit: Double? = nil) {
        self.name = base.rawValue
        self.systemImage = base.systemImage
        self.isCustom = false
        self.budgetLimit = budgetLimit
    }

    init(customName: String, systemImage: String = "tag.fill", budgetLimit: Double? = nil) {
        self.name = customName
        self.systemImage = systemImage
        self.isCustom = true
        self.budgetLimit = budgetLimit
    }
}
