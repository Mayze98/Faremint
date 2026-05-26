import UIKit

enum PDFExporter {

    private static let pageWidth: CGFloat  = 612   // US Letter
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat     = 50

    // App theme colors (matching Theme.swift)
    private static let accentTeal   = UIColor(red: 0.306, green: 0.800, blue: 0.769, alpha: 1) // #4ECDC4
    private static let gradientStart = UIColor(red: 0.659, green: 0.902, blue: 0.812, alpha: 1) // #A8E6CF
    private static let gradientEnd   = UIColor(red: 0.533, green: 0.831, blue: 0.886, alpha: 1) // #88D4E2

    // Category colors mirroring Theme.categoryColors
    private static let categoryColorMap: [String: UIColor] = [
        "Food & Drinks":   .systemOrange,
        "Transportation":  .systemBlue,
        "Sightseeing":     .systemPurple,
        "Activities":      .systemMint,
        "Flight":          .systemCyan,
        "Hotels":          .systemPink,
        "Shopping":        .systemIndigo,
        "Souvenir":        .systemGreen
    ]

    private static func colorFor(category: String) -> UIColor {
        categoryColorMap[category] ?? accentTeal
    }

    // MARK: - Public API

    /// Generates a PDF with a trip summary section and a tax report section.
    static func pdfData(for trips: [Trip], currencyCode: String) -> Data? {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        return renderer.pdfData { ctx in
            // ── Page 1+: Trip summaries ──────────────────────────────────────
            ctx.beginPage()
            var y: CGFloat = 0

            // Themed header banner
            drawHeaderBanner(title: "Faremint — Trip Summary",
                             subtitle: Date.now.formatted(date: .long, time: .omitted),
                             ctx: ctx, y: &y)

            for trip in trips {
                if y > pageHeight - 120 { ctx.beginPage(); y = margin }

                // Trip card background
                let cardHeight: CGFloat = 26 + CGFloat(
                    Dictionary(grouping: trip.expenses) { $0.categoryName }.count
                ) * 26 + 12
                let cardRect = CGRect(x: margin - 8, y: y - 4,
                                      width: pageWidth - (margin - 8) * 2, height: cardHeight)
                UIColor(white: 0.97, alpha: 1).setFill()
                UIBezierPath(roundedRect: cardRect, cornerRadius: 6).fill()
                accentTeal.withAlphaComponent(0.4).setStroke()
                let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 6)
                border.lineWidth = 0.5
                border.stroke()

                // Trip header
                let totalSpent = trip.expenses.reduce(0) { $0 + $1.amount }
                draw(trip.name, at: &y, ctx: ctx,
                     font: .boldSystemFont(ofSize: 13), color: .black)
                let overBudget = trip.budget > 0 && totalSpent > trip.budget
                let spentColor: UIColor = overBudget ? .systemRed : UIColor(white: 0.3, alpha: 1)
                draw(
                    "\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \((trip.endDate ?? trip.startDate).formatted(date: .abbreviated, time: .omitted))   |   Budget: \(fmt(trip.budget, currencyCode))   |   Spent: \(fmt(totalSpent, currencyCode))",
                    at: &y, ctx: ctx, font: .systemFont(ofSize: 10), color: spentColor
                )
                y += 4

                // Category bar + amounts
                let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
                let sorted = grouped.sorted {
                    ($0.value.reduce(0) { $0 + $1.amount }) > ($1.value.reduce(0) { $0 + $1.amount })
                }
                for (category, expenses) in sorted {
                    if y > pageHeight - 40 { ctx.beginPage(); y = margin }
                    let total = expenses.reduce(0) { $0 + $1.amount }
                    let barMax = pageWidth - margin * 2 - 200
                    let barFill = trip.budget > 0 ? min(CGFloat(total / trip.budget) * barMax, barMax) : 0

                    // Category label
                    let labelAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor.black
                    ]
                    let label = "  \(category)"
                    label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)

                    // Bar background
                    UIColor(white: 0.88, alpha: 1).setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y + 13, width: barMax, height: 5),
                                 cornerRadius: 2.5).fill()
                    // Bar fill using category colour
                    colorFor(category: category).setFill()
                    if barFill > 0 {
                        UIBezierPath(roundedRect: CGRect(x: margin, y: y + 13, width: barFill, height: 5),
                                     cornerRadius: 2.5).fill()
                    }

                    // Amount
                    let amtAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                        .foregroundColor: UIColor.black
                    ]
                    fmt(total, currencyCode).draw(
                        at: CGPoint(x: margin + barMax + 8, y: y),
                        withAttributes: amtAttrs
                    )
                    y += 24
                }
                y += 18
            }

            // ── Tax Report ──────────────────────────────────────────────────
            ctx.beginPage()
            var y2: CGFloat = 0

            drawHeaderBanner(title: "Tax Report — All Expenses",
                             subtitle: "Generated: \(Date.now.formatted(date: .long, time: .omitted))",
                             ctx: ctx, y: &y2)

            // Table header row with tinted background
            accentTeal.withAlphaComponent(0.15).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y2, width: pageWidth - margin * 2, height: 18)).fill()
            drawRow(date: "Date", trip: "Trip", category: "Category",
                    title: "Description", amount: "Amount", at: &y2, ctx: ctx,
                    font: .boldSystemFont(ofSize: 10), color: .black)
            accentTeal.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y2, width: pageWidth - margin * 2, height: 1)).fill()
            y2 += 4

            let allExpenses = trips.flatMap(\.expenses).sorted { $0.createdAt < $1.createdAt }
            for (i, expense) in allExpenses.enumerated() {
                if y2 > pageHeight - 30 { ctx.beginPage(); y2 = margin }
                // Alternate row shading
                if i % 2 == 0 {
                    UIColor(white: 0.96, alpha: 1).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y2, width: pageWidth - margin * 2, height: 16)).fill()
                }
                let tripName = expense.trip?.name ?? ""
                drawRow(
                    date: expense.createdAt.formatted(.dateTime.day().month(.abbreviated)),
                    trip: tripName,
                    category: expense.categoryName,
                    title: expense.title,
                    amount: fmt(expense.amount, currencyCode),
                    at: &y2, ctx: ctx,
                    font: .systemFont(ofSize: 10),
                    color: .black
                )
            }
        }
    }

    /// Writes the PDF to a temporary file and returns the URL for ShareLink.
    static func pdfFileURL(for trips: [Trip], currencyCode: String) -> URL? {
        guard let data = pdfData(for: trips, currencyCode: currencyCode) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("travelwise-pro-summary.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Drawing helpers

    /// Draws a full-width gradient header banner with a large title and subtitle.
    private static func drawHeaderBanner(
        title: String,
        subtitle: String,
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat
    ) {
        let bannerHeight: CGFloat = 70
        let bannerRect = CGRect(x: 0, y: 0, width: pageWidth, height: bannerHeight)

        // Draw gradient manually using two rects blended
        gradientStart.setFill()
        UIBezierPath(rect: bannerRect).fill()

        // Overlay second colour with alpha for a simple gradient effect
        gradientEnd.withAlphaComponent(0.5).setFill()
        UIBezierPath(rect: CGRect(x: pageWidth / 2, y: 0, width: pageWidth / 2, height: bannerHeight)).fill()

        // Title text
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: margin, y: 14), withAttributes: titleAttrs)

        // Subtitle text
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor(white: 0.2, alpha: 1)
        ]
        subtitle.draw(at: CGPoint(x: margin, y: 42), withAttributes: subtitleAttrs)

        // Bottom accent line
        accentTeal.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: bannerHeight - 2, width: pageWidth, height: 2)).fill()

        y = bannerHeight + 16
    }

    private static func draw(
        _ text: String,
        at y: inout CGFloat,
        ctx: UIGraphicsPDFRendererContext,
        font: UIFont,
        color: UIColor = .black
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        y += size.height + 4
    }

    private static func drawRow(
        date: String, trip: String, category: String,
        title: String, amount: String,
        at y: inout CGFloat,
        ctx: UIGraphicsPDFRendererContext,
        font: UIFont,
        color: UIColor = .black
    ) {
        let cols: [(String, CGFloat)] = [
            (date,     margin),
            (trip,     margin + 62),
            (category, margin + 148),
            (title,    margin + 242),
            (amount,   pageWidth - margin - 70)
        ]
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        for (text, x) in cols {
            text.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
        y += font.lineHeight + 4
    }

    private static func fmt(_ amount: Double, _ code: String) -> String {
        CurrencyHelper.format(amount, code: code)
    }
}
