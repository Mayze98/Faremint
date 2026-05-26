import SwiftUI
import SwiftData
import MapKit

struct ExpenseDetailView: View {
    let expense: Expense
    let currencyCode: String
    var categories: [ExpenseCategory] = []
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestoreService
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.categoryName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.colorForCategory(expense.categoryName))
                            Text(expense.title)
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        Circle()
                            .fill(Theme.colorForCategory(expense.categoryName).opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: categoryIcon)
                                    .foregroundStyle(Theme.colorForCategory(expense.categoryName))
                            }
                    }

                    Divider()

                    // Amount
                    HStack {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyHelper.format(expense.amount, code: currencyCode))
                            .font(.title3.weight(.bold))
                    }

                    // Split info
                    if let split = expense.splitPercent {
                        HStack {
                            Text("Original amount")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyHelper.format(expense.originalAmount, code: currencyCode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Your share")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(split))%")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.accentTeal.opacity(0.15), in: Capsule())
                                .foregroundStyle(Theme.accentTeal)
                        }
                    }

                    // Date
                    HStack {
                        Text("Date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(expense.createdAt, format: .dateTime.month(.wide).day().year())
                            .font(.subheadline)
                    }
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))

                // Photo
                if let photoData = expense.photoData, let uiImage = UIImage(data: photoData) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Picture", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                // Notes
                if !expense.note.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Notes", systemImage: "note.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(expense.note)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                // Location
                if let lat = expense.latitude, let lon = expense.longitude {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Location", systemImage: "mappin.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.locationName ?? String(format: "%.4f, %.4f", lat, lon))
                                    .font(.subheadline)
                                if expense.locationName != nil {
                                    Text(String(format: "%.4f, %.4f", lat, lon))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                let item = MKMapItem(placemark: placemark)
                                item.name = expense.locationName ?? expense.title
                                item.openInMaps()
                            } label: {
                                Label("Open", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.accentTeal)
                            }
                            .buttonStyle(.plain)
                        }

                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Marker(expense.locationName ?? "", coordinate: coord)
                                .tint(Theme.accentTeal)
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                // Delete button
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Expense", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditExpenseSheet(
                expense: expense,
                categories: categories.isEmpty ? BaseCategory.allCases.map { ExpenseCategory(base: $0) } : categories,
                currencyCode: currencyCode
            )
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let trip = expense.trip
                if let tripFID = trip?.firestoreID {
                    firestoreService.deleteExpense(firestoreID: expense.firestoreID, tripFirestoreID: tripFID, photoURL: expense.photoURL)
                }
                modelContext.delete(expense)
                if let trip { NotificationService.shared.checkBudgetThresholds(for: trip) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(expense.title)\"? This cannot be undone.")
        }
    }

    private var categoryIcon: String {
        if let tripCategory = expense.trip?.categories.first(where: { $0.name == expense.categoryName }) {
            return tripCategory.systemImage
        }
        let base = BaseCategory.allCases.first { $0.rawValue == expense.categoryName }
        return base?.systemImage ?? "tag.fill"
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailView(
            expense: Expense(title: "Sushi dinner", amount: 85, categoryName: "Food & Drinks", note: "Great omakase at Sukiyabashi Jiro"),
            currencyCode: "USD"
        )
    }
    .environment(FirestoreService())
}
