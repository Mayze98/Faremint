import SwiftUI
import SwiftData

struct BubbleClusterView: View {
    let trips: [Trip]
    @AppStorage("userName") private var userName = "Traveler"
    var onTripTapped: (Trip) -> Void = { _ in }

    @State private var spinAngle: Double = 0
    @State private var baseAngle: Double = 0
    @State private var lastDragAngle: Double = 0

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.size
            let centerPoint = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            let spendRatios = trips.map { trip in
                trip.budget > 0 ? trip.totalSpent / trip.budget : 0
            }
            let centerRadius: CGFloat = 45

            let radiiPairs: [(id: Int, radius: CGFloat)] = trips.enumerated().map { index, trip in
                let ratio = trip.budget > 0 ? trip.totalSpent / trip.budget : 0
                return (id: index, radius: BubbleLayoutCalculator.radius(forSpendRatio: ratio, allRatios: spendRatios))
            }

            let placements = BubbleLayoutCalculator.packCircles(
                radii: radiiPairs,
                in: bounds,
                centerRadius: centerRadius
            )

            ZStack {
                // Center user bubble
                if placements.contains(where: { $0.id == -1 }) {
                    CenterBubbleView(name: userName, radius: centerRadius)
                        .position(centerPoint)
                }

                // Trip bubbles — rotated around center
                ForEach(Array(trips.enumerated()), id: \.element.persistentModelID) { index, trip in
                    if let placement = placements.first(where: { $0.id == index }) {
                        let rotated = rotatePoint(placement.center, around: centerPoint, by: spinAngle)
                        BubbleView(trip: trip, radius: placement.radius)
                            .position(rotated)
                            .onTapGesture {
                                onTripTapped(trip)
                            }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let current = angleFromCenter(value.location, center: centerPoint)
                        let start = angleFromCenter(value.startLocation, center: centerPoint)
                        spinAngle = baseAngle + (current - start)
                    }
                    .onEnded { value in
                        let current = angleFromCenter(value.location, center: centerPoint)
                        let start = angleFromCenter(value.startLocation, center: centerPoint)
                        let dragDelta = current - start

                        // Calculate velocity from predicted end
                        let predicted = angleFromCenter(value.predictedEndLocation, center: centerPoint)
                        let momentum = (predicted - current) * 3

                        baseAngle += dragDelta
                        spinAngle = baseAngle

                        withAnimation(.easeOut(duration: 1.2)) {
                            spinAngle = baseAngle + momentum
                        }
                        baseAngle += momentum
                    }
            )
        }
    }

    private func angleFromCenter(_ point: CGPoint, center: CGPoint) -> Double {
        atan2(Double(point.y - center.y), Double(point.x - center.x))
    }

    private func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: Double) -> CGPoint {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: center.x + CGFloat(dx * cosA - dy * sinA),
            y: center.y + CGFloat(dx * sinA + dy * cosA)
        )
    }

}

#Preview {
    BubbleClusterView(trips: [])
        .modelContainer(SampleData.container)
}
