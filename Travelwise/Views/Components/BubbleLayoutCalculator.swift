import CoreGraphics

struct CirclePlacement: Identifiable {
    let id: Int
    var center: CGPoint
    let radius: CGFloat
}

enum BubbleLayoutCalculator {
    /// Packs circles into bounds without overlap using force-directed simulation.
    /// - Parameters:
    ///   - radii: Array of (id, radius) pairs, where id matches the trip index
    ///   - bounds: Available area size
    ///   - centerRadius: Optional fixed center bubble radius (for user avatar)
    /// - Returns: Array of positioned circles
    static func packCircles(
        radii: [(id: Int, radius: CGFloat)],
        in bounds: CGSize,
        centerRadius: CGFloat? = nil
    ) -> [CirclePlacement] {
        guard !radii.isEmpty else { return [] }

        let cx = bounds.width / 2
        let cy = bounds.height / 2
        let center = CGPoint(x: cx, y: cy)

        // Sort by radius descending (place largest first)
        let sorted = radii.sorted { $0.radius > $1.radius }

        // Initial spiral placement
        var placements: [CirclePlacement] = []

        // Add center bubble if specified
        let hasCenterBubble = centerRadius != nil
        if let cr = centerRadius {
            placements.append(CirclePlacement(id: -1, center: center, radius: cr))
        }

        let angleStep: CGFloat = .pi * (3 - sqrt(5)) // Golden angle
        var spiralRadius: CGFloat = hasCenterBubble ? (centerRadius! + 10) : 0

        for (i, item) in sorted.enumerated() {
            let angle = CGFloat(i) * angleStep
            spiralRadius += item.radius * 0.4
            let x = cx + cos(angle) * spiralRadius
            let y = cy + sin(angle) * spiralRadius
            placements.append(CirclePlacement(id: item.id, center: CGPoint(x: x, y: y), radius: item.radius))
        }

        // Run collision resolution iterations
        let iterations = 150
        let padding: CGFloat = 4

        for _ in 0..<iterations {
            // Collision resolution
            for i in 0..<placements.count {
                for j in (i + 1)..<placements.count {
                    let dx = placements[j].center.x - placements[i].center.x
                    let dy = placements[j].center.y - placements[i].center.y
                    let dist = sqrt(dx * dx + dy * dy)
                    let minDist = placements[i].radius + placements[j].radius + padding

                    if dist < minDist && dist > 0.01 {
                        let overlap = (minDist - dist) / 2
                        let nx = dx / dist
                        let ny = dy / dist

                        // Center bubble is fixed
                        if placements[i].id == -1 {
                            placements[j].center.x += nx * overlap * 2
                            placements[j].center.y += ny * overlap * 2
                        } else if placements[j].id == -1 {
                            placements[i].center.x -= nx * overlap * 2
                            placements[i].center.y -= ny * overlap * 2
                        } else {
                            placements[i].center.x -= nx * overlap
                            placements[i].center.y -= ny * overlap
                            placements[j].center.x += nx * overlap
                            placements[j].center.y += ny * overlap
                        }
                    }
                }
            }

            // Centering gravity (skip center bubble)
            let gravity: CGFloat = 0.02
            for i in 0..<placements.count where placements[i].id != -1 {
                let dx = center.x - placements[i].center.x
                let dy = center.y - placements[i].center.y
                placements[i].center.x += dx * gravity
                placements[i].center.y += dy * gravity
            }

            // Boundary clamping
            for i in 0..<placements.count where placements[i].id != -1 {
                let r = placements[i].radius
                placements[i].center.x = max(r, min(bounds.width - r, placements[i].center.x))
                placements[i].center.y = max(r, min(bounds.height - r, placements[i].center.y))
            }
        }

        return placements
    }

    /// Calculates bubble radius based on the trip's spend ratio (totalSpent / budget).
    /// Trips that have spent a larger proportion of their budget get bigger bubbles.
    static func radius(forSpendRatio ratio: Double, allRatios: [Double], minRadius: CGFloat = 40, maxRadius: CGFloat = 75) -> CGFloat {
        guard let maxRatio = allRatios.max(), maxRatio > 0 else { return minRadius }
        let minRatio = allRatios.min() ?? 0
        let range = maxRatio - minRatio
        guard range > 0 else { return (minRadius + maxRadius) / 2 }
        let normalized = (ratio - minRatio) / range
        return minRadius + CGFloat(normalized) * (maxRadius - minRadius)
    }
}
