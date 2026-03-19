import Foundation

struct BubblePlacement {
    let id: Int
    let center: CGPoint
    let radius: CGFloat
}

enum BubbleLayoutCalculator {

    // MARK: - Radius Sizing

    /// Maps a spend ratio to a bubble radius, scaled relative to all ratios.
    /// Minimum radius is 35, maximum is 70.
    static func radius(forSpendRatio ratio: Double, allRatios: [Double]) -> CGFloat {
        let minRadius: CGFloat = 35
        let maxRadius: CGFloat = 70

        let maxRatio = allRatios.max() ?? 1
        let minRatio = allRatios.min() ?? 0

        guard maxRatio > minRatio else {
            return (minRadius + maxRadius) / 2
        }

        let normalized = (ratio - minRatio) / (maxRatio - minRatio)
        return minRadius + CGFloat(normalized) * (maxRadius - minRadius)
    }

    // MARK: - Circle Packing

    /// Packs circles around a center bubble, returning placements for both the
    /// center (id == -1) and each trip bubble.
    static func packCircles(
        radii: [(id: Int, radius: CGFloat)],
        in bounds: CGSize,
        centerRadius: CGFloat
    ) -> [BubblePlacement] {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        var placements: [BubblePlacement] = []

        // Place center bubble
        placements.append(BubblePlacement(id: -1, center: center, radius: centerRadius))

        guard !radii.isEmpty else { return placements }

        // Sort by radius descending so larger bubbles are placed first
        let sorted = radii.sorted { $0.radius > $1.radius }

        // Place bubbles in a spiral pattern around center
        let gap: CGFloat = 6
        var angleOffset: Double = -.pi / 2  // Start from top

        for item in sorted {
            let distance = centerRadius + item.radius + gap
            var placed = false

            // Try placing at increasing distances from center
            var tryDistance = distance
            let maxDistance = max(bounds.width, bounds.height)

            while !placed && tryDistance < maxDistance {
                // Try multiple angles at this distance
                let angleStep = Double.pi / 18  // 10-degree steps
                for i in 0..<36 {
                    let angle = angleOffset + Double(i) * angleStep
                    let candidate = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * tryDistance,
                        y: center.y + CGFloat(sin(angle)) * tryDistance
                    )

                    if !overlaps(candidate, radius: item.radius, with: placements, gap: gap) {
                        placements.append(BubblePlacement(id: item.id, center: candidate, radius: item.radius))
                        angleOffset += Double.pi * 0.4  // Offset next bubble's starting angle
                        placed = true
                        break
                    }
                }
                tryDistance += 4
            }

            // Fallback: place at computed distance even if overlapping
            if !placed {
                let angle = angleOffset
                let fallback = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * distance,
                    y: center.y + CGFloat(sin(angle)) * distance
                )
                placements.append(BubblePlacement(id: item.id, center: fallback, radius: item.radius))
                angleOffset += Double.pi * 0.4
            }
        }

        return placements
    }

    // MARK: - Helpers

    private static func overlaps(
        _ point: CGPoint,
        radius: CGFloat,
        with placements: [BubblePlacement],
        gap: CGFloat
    ) -> Bool {
        for p in placements {
            let dx = point.x - p.center.x
            let dy = point.y - p.center.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < radius + p.radius + gap {
                return true
            }
        }
        return false
    }
}
