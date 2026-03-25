import UIKit

enum PDFExporter {

    private static let pageWidth: CGFloat  = 612   // US Letter
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat     = 50

    // MARK: - Public API

    /// Generates a PDF with a trip summary section and a tax report section.
    static func pdfData(for trips: [Trip], currencyCode: String) -> Data? {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        return renderer.pdfData { ctx in
            // ── Page 1+: Trip summaries ──────────────────────────────────────
            ctx.beginPage()
            var y = margin

            draw("Travelwise — Trip Summary", at: &y, ctx: ctx, font: .boldSystemFont(ofSize: 20))
            draw(Date.now.formatted(date: .long, time: .omitted), at: &y, ctx: ctx,
                 font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 12

            for trip in trips {
                if y > pageHeight - 120 { ctx.beginPage(); y = margin }

                // Trip header
                let totalSpent = trip.expenses.reduce(0) { $0 + $1.amount }
                draw(trip.name, at: &y, ctx: ctx, font: .boldSystemFont(ofSize: 14))
                draw(
                    "\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))   |   Budget: \(fmt(trip.budget, currencyCode))   |   Spent: \(fmt(totalSpent, currencyCode))",
                    at: &y, ctx: ctx, font: .systemFont(ofSize: 11), color: .secondaryLabel
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
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.label
                    ]
                    let label = "  \(category)"
                    label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)

                    // Bar background
                    UIColor.systemGray5.setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y + 14, width: barMax, height: 6),
                                 cornerRadius: 3).fill()
                    // Bar fill
                    UIColor.systemTeal.setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y + 14, width: barFill, height: 6),
                                 cornerRadius: 3).fill()

                    // Amount
                    let amtAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: UIColor.label
                    ]
                    fmt(total, currencyCode).draw(
                        at: CGPoint(x: margin + barMax + 8, y: y),
                        withAttributes: amtAttrs
                    )
                    y += 26
                }
                y += 16
            }

            // ── Tax Report ──────────────────────────────────────────────────
            ctx.beginPage()
            y = margin

            draw("Tax Report — All Expenses", at: &y, ctx: ctx, font: .boldSystemFont(ofSize: 18))
            draw("Generated: \(Date.now.formatted(date: .long, time: .omitted))",
                 at: &y, ctx: ctx, font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 8

            // Table header
            drawRow(date: "Date", trip: "Trip", category: "Category",
                    title: "Description", amount: "Amount", at: &y, ctx: ctx,
                    font: .boldSystemFont(ofSize: 10))
            UIColor.separator.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 0.5)).fill()
            y += 6

            let allExpenses = trips.flatMap(\.expenses).sorted { $0.createdAt < $1.createdAt }
            for expense in allExpenses {
                if y > pageHeight - 30 { ctx.beginPage(); y = margin }
                let tripName = expense.trip?.name ?? ""
                drawRow(
                    date: expense.createdAt.formatted(.dateTime.day().month(.abbreviated)),
                    trip: tripName,
                    category: expense.categoryName,
                    title: expense.title,
                    amount: fmt(expense.amount, currencyCode),
                    at: &y, ctx: ctx,
                    font: .systemFont(ofSize: 10)
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

    private static func draw(
        _ text: String,
        at y: inout CGFloat,
        ctx: UIGraphicsPDFRendererContext,
        font: UIFont,
        color: UIColor = .label
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
        font: UIFont
    ) {
        let cols: [(String, CGFloat)] = [
            (date,     margin),
            (trip,     margin + 62),
            (category, margin + 148),
            (title,    margin + 242),
            (amount,   pageWidth - margin - 70)
        ]
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
        for (text, x) in cols {
            text.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
        y += font.lineHeight + 4
    }

    private static func fmt(_ amount: Double, _ code: String) -> String {
        CurrencyHelper.format(amount, code: code)
    }
}
