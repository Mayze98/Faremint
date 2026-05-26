import Foundation

enum CSVExporter {
    static func generateCSV(for trip: Trip) -> String {
        var csv = "Category,Title,Amount,Original Amount,Split %,Date,Notes\n"
        let sorted = trip.expenses.sorted { $0.createdAt < $1.createdAt }
        for expense in sorted {
            let fields = [
                escapeCSV(expense.categoryName),
                escapeCSV(expense.title),
                String(format: "%.2f", expense.amount),
                String(format: "%.2f", expense.originalAmount),
                expense.splitPercent.map { String(format: "%.0f", $0) } ?? "",
                expense.createdAt.formatted(date: .abbreviated, time: .omitted),
                escapeCSV(expense.note)
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return csv
    }

    static func generateCSV(for trips: [Trip]) -> String {
        var csv = "Trip,Category,Title,Amount,Original Amount,Split %,Date,Notes\n"
        for trip in trips {
            let sorted = trip.expenses.sorted { $0.createdAt < $1.createdAt }
            for expense in sorted {
                let fields = [
                    escapeCSV(trip.name),
                    escapeCSV(expense.categoryName),
                    escapeCSV(expense.title),
                    String(format: "%.2f", expense.amount),
                    String(format: "%.2f", expense.originalAmount),
                    expense.splitPercent.map { String(format: "%.0f", $0) } ?? "",
                    expense.createdAt.formatted(date: .abbreviated, time: .omitted),
                    escapeCSV(expense.note)
                ]
                csv += fields.joined(separator: ",") + "\n"
            }
        }
        return csv
    }

    static func csvFileURL(for trip: Trip) -> URL? {
        let csv = generateCSV(for: trip)
        let sanitizedName = sanitizeFilename(trip.name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedName)-expenses.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func csvFileURL(for trips: [Trip]) -> URL? {
        let csv = generateCSV(for: trips)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("travelwise-all-trips.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }

    /// Strips filesystem-unsafe characters and limits length for safe filenames.
    private static func sanitizeFilename(_ name: String) -> String {
        let cleaned = name.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
            || scalar == " " || scalar == "-" || scalar == "_"
        }
        let result = String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        let truncated = String(result.prefix(60))
        return truncated.isEmpty ? "export" : truncated
    }
}
