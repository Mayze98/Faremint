import SwiftUI

enum Theme {
    static let accentTeal = Color(hex: "4ECDC4")
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "A8E6CF"), Color(hex: "88D4E2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardBackground = Color(.systemBackground)
    static let subtitleColor = Color(.secondaryLabel)

    static let categoryColors: [String: Color] = [
        "Food & Drinks": .orange,
        "Transportation": .blue,
        "Sightseeing": .purple,
        "Flight": .cyan,
        "Hotels": .pink,
        "Souvenir": .green
    ]

    static let bubblePalette: [String] = [
        "4ECDC4", "FF6B6B", "45B7D1", "96CEB4",
        "FFEAA7", "DDA0DD", "98D8C8", "F7DC6F"
    ]

    static func colorForCategory(_ name: String) -> Color {
        categoryColors[name] ?? .gray
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
