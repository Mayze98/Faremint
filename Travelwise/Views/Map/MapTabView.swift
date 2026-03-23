import SwiftUI
import SwiftData
import MapKit

// MARK: - MapTabView
//
// Shows all expenses that have a location attached as pins on an Apple Map.
// A trip filter pill-bar at the top lets the user narrow pins to a single trip.
// Tapping a pin shows a callout sheet with the expense title, amount, category,
// trip name, and a link to open in Apple Maps.

struct MapTabView: View {
    @Query private var trips: [Trip]
    @State private var selectedTripID: String? = nil   // nil = show all
    @State private var selectedExpense: Expense? = nil
    @State private var mapPosition: MapCameraPosition = .automatic

    // Expenses that have a valid location
    private var mappableExpenses: [Expense] {
        let allExpenses = trips.flatMap { $0.expenses }
        let located = allExpenses.filter { $0.latitude != nil && $0.longitude != nil }
        if let tripID = selectedTripID {
            return located.filter { $0.trip?.firestoreID == tripID }
        }
        return located
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map

                // Trip filter bar
                if trips.contains(where: { $0.expenses.contains { $0.latitude != nil } }) {
                    tripFilterBar
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedExpense) { expense in
                ExpenseMapCallout(expense: expense)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $mapPosition) {
            ForEach(mappableExpenses) { expense in
                if let lat = expense.latitude, let lon = expense.longitude {
                    Annotation(
                        expense.title,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        anchor: .bottom
                    ) {
                        ExpenseMapPin(expense: expense)
                            .onTapGesture {
                                selectedExpense = expense
                            }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            if mappableExpenses.isEmpty {
                emptyState
            }
        }
        .onChange(of: selectedTripID) { _, _ in
            fitMapToExpenses()
        }
        .onAppear {
            fitMapToExpenses()
        }
    }

    // MARK: - Trip filter bar

    private var tripFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                filterPill(title: "All trips", tripID: nil, colorHex: "4ECDC4")

                ForEach(trips.filter { trip in
                    trip.expenses.contains { $0.latitude != nil && $0.longitude != nil }
                }) { trip in
                    filterPill(title: trip.name, tripID: trip.firestoreID, colorHex: trip.colorHex)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial, in: Capsule().inset(by: -6))
        .padding(.horizontal, 12)
    }

    private func filterPill(title: String, tripID: String?, colorHex: String) -> some View {
        let isSelected = selectedTripID == tripID
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTripID = tripID
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? Color(hex: colorHex)
                        : Color(.systemGray5),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No pinned expenses")
                .font(.headline)
            Text("Add a location when creating or editing an expense to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Camera fit

    private func fitMapToExpenses() {
        let expenses = mappableExpenses
        guard !expenses.isEmpty else { return }

        if expenses.count == 1,
           let lat = expenses[0].latitude,
           let lon = expenses[0].longitude {
            mapPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
            return
        }

        let coords = expenses.compactMap { e -> CLLocationCoordinate2D? in
            guard let lat = e.latitude, let lon = e.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let minLat = coords.map(\.latitude).min()!
        let maxLat = coords.map(\.latitude).max()!
        let minLon = coords.map(\.longitude).min()!
        let maxLon = coords.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.05)
        )
        mapPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - ExpenseMapPin

private struct ExpenseMapPin: View {
    let expense: Expense

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.colorForCategory(expense.categoryName))
                .frame(width: 36, height: 36)
                .shadow(radius: 3, y: 2)
            Image(systemName: iconForCategory(expense.categoryName))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func iconForCategory(_ name: String) -> String {
        switch name {
        case "Food & Drinks": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Flight": return "airplane"
        case "Hotels": return "bed.double.fill"
        case "Shopping": return "bag.fill"
        case "Activities": return "figure.walk"
        case "Sightseeing": return "binoculars.fill"
        case "Souvenir": return "gift.fill"
        default: return "mappin.fill"
        }
    }
}

// MARK: - ExpenseMapCallout

private struct ExpenseMapCallout: View {
    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.colorForCategory(expense.categoryName).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.colorForCategory(expense.categoryName))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.title)
                        .font(.headline)
                    Text(expense.categoryName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(CurrencyHelper.format(expense.amount, code: UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"))
                        .font(.title3.weight(.semibold))
                    if let tripName = expense.trip?.name {
                        Text(tripName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            // Location info + Apple Maps link
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Theme.accentTeal)
                Text(expense.locationName ?? coordinateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let lat = expense.latitude, let lon = expense.longitude {
                    Button {
                        openInMaps(lat: lat, lon: lon)
                    } label: {
                        Label("Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accentTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            if !expense.note.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(expense.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding()
            }
        }
        .presentationBackground(.background)
    }

    private var categoryIcon: String {
        switch expense.categoryName {
        case "Food & Drinks": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Flight": return "airplane"
        case "Hotels": return "bed.double.fill"
        case "Shopping": return "bag.fill"
        case "Activities": return "figure.walk"
        case "Sightseeing": return "binoculars.fill"
        case "Souvenir": return "gift.fill"
        default: return "dollarsign.circle.fill"
        }
    }

    private var coordinateString: String {
        guard let lat = expense.latitude, let lon = expense.longitude else { return "Unknown" }
        return String(format: "%.4f, %.4f", lat, lon)
    }

    private func openInMaps(lat: Double, lon: Double) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let item = MKMapItem(placemark: placemark)
        item.name = expense.locationName ?? expense.title
        item.openInMaps()
    }
}

#Preview {
    MapTabView()
        .modelContainer(SampleData.container)
}
