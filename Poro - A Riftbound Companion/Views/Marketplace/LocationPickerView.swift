import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var pickedLocation: PickedLocation?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var locationService = LocationService()
    @State private var isGettingLocation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        useCurrentLocation()
                    } label: {
                        HStack {
                            if isGettingLocation {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text("Usar localização atual")
                        }
                    }
                    .disabled(isGettingLocation || locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted)
                }

                if isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("A pesquisar...")
                            Spacer()
                        }
                    }
                } else if !results.isEmpty {
                    Section("Resultados") {
                        ForEach(results, id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(locationName(from: item))
                                        .foregroundStyle(.primary)
                                    if let subtitle = locationSubtitle(from: item) {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Pesquisar cidade ou localidade...")
            .onChange(of: searchText) { scheduleSearch() }
            .navigationTitle("Localização")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { results = []; return }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }

    private func search(query: String) async {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            results = response.mapItems
        } catch {
            results = []
        }
        isSearching = false
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let name = locationName(from: item)
        pickedLocation = PickedLocation(name: name, latitude: coord.latitude, longitude: coord.longitude)
        dismiss()
    }

    private func useCurrentLocation() {
        isGettingLocation = true
        locationService.requestLocation()
        Task {
            for _ in 0..<30 {
                if let loc = locationService.currentLocation {
                    await reverseGeocode(location: loc)
                    return
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            isGettingLocation = false
        }
    }

    private func reverseGeocode(location: CLLocation) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                pickedLocation = PickedLocation(
                    name: name.isEmpty ? "Localização atual" : name,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                dismiss()
            }
        } catch {}
        isGettingLocation = false
    }

    private func locationName(from item: MKMapItem) -> String {
        let locality = item.placemark.locality
        let admin = item.placemark.administrativeArea
        let name = [locality, admin].compactMap { $0 }.joined(separator: ", ")
        return name.isEmpty ? (item.name ?? "") : name
    }

    private func locationSubtitle(from item: MKMapItem) -> String? {
        let country = item.placemark.country
        let postal = item.placemark.postalCode
        return [postal, country].compactMap { $0 }.joined(separator: " ").isEmpty ? nil :
            [postal, country].compactMap { $0 }.joined(separator: " ")
    }
}
