import SwiftUI

struct BubbleClusterView: View {
    let trips: [Trip]
    @AppStorage("userName") private var userName = "Traveler"
    var onTripTapped: (Trip) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.size
            let allBudgets = trips.map(\.budget)
            let centerRadius: CGFloat = 45

            let radiiPairs: [(id: Int, radius: CGFloat)] = trips.enumerated().map { index, trip in
                (id: index, radius: BubbleLayoutCalculator.radius(for: trip.budget, allBudgets: allBudgets))
            }

            let placements = BubbleLayoutCalculator.packCircles(
                radii: radiiPairs,
                in: bounds,
                centerRadius: centerRadius
            )

            ZStack {
                // Center user bubble
                if let centerPlacement = placements.first(where: { $0.id == -1 }) {
                    CenterBubbleView(name: userName, radius: centerRadius)
                        .position(centerPlacement.center)
                }

                // Trip bubbles
                ForEach(Array(trips.enumerated()), id: \.element.persistentModelID) { index, trip in
                    if let placement = placements.first(where: { $0.id == index }) {
                        BubbleView(trip: trip, radius: placement.radius)
                            .position(placement.center)
                            .onTapGesture {
                                onTripTapped(trip)
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    BubbleClusterView(trips: [])
        .modelContainer(SampleData.container)
}
