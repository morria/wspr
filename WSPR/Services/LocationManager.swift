import Foundation
import CoreLocation
import Observation

/// Thin wrapper around CoreLocation providing the device coordinate and derived grid.
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// The 6-character Maidenhead grid for the current location, if known.
    var gridSquare: String? {
        guard let coordinate else { return nil }
        return MaidenheadLocator.gridSquare(from: coordinate, length: 6)
    }

    override init() {
        authorizationStatus = .notDetermined
        super.init()
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let coord = last.coordinate
        Task { @MainActor in self.coordinate = coord }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: keep the last known coordinate.
    }
}
