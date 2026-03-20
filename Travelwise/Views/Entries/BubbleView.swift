import SwiftUI

struct BubbleView: View {
    let trip: Trip
    let radius: CGFloat
    @AppStorage("currencyCode") private var homeCurrency = "CAD"

    private var fontSize: CGFloat {
        max(8, radius * 0.18)
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: trip.colorHex).opacity(0.85),
                        Color(hex: trip.colorHex)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: Color(hex: trip.colorHex).opacity(0.3), radius: 8, y: 4)
            .overlay {
                VStack(spacing: 1) {
                    Text(trip.name)
                        .font(.system(size: fontSize + 1, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(CurrencyHelper.format(trip.totalSpent, code: homeCurrency))
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))

                    Text("\(Int(trip.budgetUsedPercent))% of budget")
                        .font(.system(size: max(7, fontSize - 2), design: .rounded))
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(6)
            }
    }
}

struct CenterBubbleView: View {
    let name: String
    let radius: CGFloat

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "6CB4EE"),
                        Color(hex: "4A90D9")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: Color(hex: "4A90D9").opacity(0.3), radius: 8, y: 4)
            .overlay {
                Text(name)
                    .font(.system(size: radius * 0.3, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    BubbleView(
        trip: {
            let t = Trip(name: "Tokyo Adventure", budget: 5000, colorHex: "45B7D1")
            return t
        }(),
        radius: 60
    )
}
