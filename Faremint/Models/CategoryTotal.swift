import Foundation

struct CategoryTotal: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let percentage: Double
}
