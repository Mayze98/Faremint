import SwiftUI

enum BaseCategory: String, Codable, CaseIterable, Identifiable {
    case foodAndDrinks = "Food & Drinks"
    case transportation = "Transportation"
    case sightseeing = "Sightseeing"
    case flight = "Flight"
    case hotels = "Hotels"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .foodAndDrinks: "fork.knife"
        case .transportation: "car.fill"
        case .sightseeing: "binoculars.fill"
        case .flight: "airplane"
        case .hotels: "bed.double.fill"
        }
    }
}

struct ExpenseCategory: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let systemImage: String
    let isCustom: Bool

    init(base: BaseCategory) {
        self.name = base.rawValue
        self.systemImage = base.systemImage
        self.isCustom = false
    }

    init(customName: String, systemImage: String = "tag.fill") {
        self.name = customName
        self.systemImage = systemImage
        self.isCustom = true
    }
}
