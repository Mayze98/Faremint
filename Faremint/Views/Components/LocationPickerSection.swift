import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationPickerSection
//
// A Form section that lets the user attach an optional location to an expense.
// Provides:
//   • A search field with MKLocalSearch autocomplete results
//   • A "Use current location" button via CoreLocation
//   • A small map preview once a location is set
//   • A remove button to clear the location

struct LocationPickerSection: View {
    @Binding var locationName: String?
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var locationManager = CLLocationManager()
    @State private var isRequestingLocation = false
    @State private var locationError: String?

    private var hasLocation: Bool { latitude != nil && longitude != nil }

    var body: some View {
        Section {
            if hasLocation {
                attachedLocationRow
            } else {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a place…", text: $searchText)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, newValue in
                            searchPlaces(query: newValue)
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // GPS button
                Button {
                    requestCurrentLocation()
                } label: {
                    HStack {
                        if isRequestingLocation {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundStyle(Theme.accentTeal)
                        }
                        Text(isRequestingLocation ? "Getting location…" : "Use current location")
                            .foregroundStyle(isRequestingLocation ? .secondary : Theme.accentTeal)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRequestingLocation)

                if let error = locationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Search results
                if isSearching {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Searching…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if !searchResults.isEmpty {
                    ForEach(searchResults, id: \.self) { item in
                        Button {
                            selectMapItem(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if let address = item.placemark.formattedAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("Location")
        }
    }

    // MARK: - Attached location row

    private var attachedLocationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Theme.accentTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName ?? "Custom location")
                        .font(.subheadline)
                    if let lat = latitude, let lon = longitude {
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    clearLocation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Mini map preview
            if let lat = latitude, let lon = longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(locationName ?? "", coordinate: coord)
                        .tint(Theme.accentTeal)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func selectMapItem(_ item: MKMapItem) {
        latitude = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
        locationName = item.name ?? item.placemark.formattedAddress
        searchText = ""
        searchResults = []
    }

    private func clearLocation() {
        latitude = nil
        longitude = nil
        locationName = nil
        searchText = ""
        searchResults = []
        locationError = nil
    }

    private func searchPlaces(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            DispatchQueue.main.async {
                isSearching = false
                searchResults = response?.mapItems ?? []
            }
        }
    }

    private func requestCurrentLocation() {
        locationError = nil
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // After authorization the user taps again
        case .denied, .restricted:
            locationError = "Location access denied. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            isRequestingLocation = true
            locationManager.requestLocation()
            // Poll once — using a Task+sleep to avoid requiring a delegate
            Task {
                // Give CLLocationManager up to 5 seconds to return a location
                for _ in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(500))
                    if let loc = locationManager.location {
                        await reverseGeocode(loc.coordinate)
                        return
                    }
                }
                await MainActor.run {
                    isRequestingLocation = false
                    locationError = "Could not determine location."
                }
            }
        @unknown default:
            break
        }
    }

    @MainActor
    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async {
        latitude = coord.latitude
        longitude = coord.longitude
        isRequestingLocation = false
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let placemark = try? await geocoder.reverseGeocodeLocation(clLocation).first {
            locationName = placemark.name ?? placemark.locality ?? "Current location"
        } else {
            locationName = "Current location"
        }
    }
}

// MARK: - MKPlacemark helper

private extension MKPlacemark {
    var formattedAddress: String? {
        [subLocality, locality, administrativeArea, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
