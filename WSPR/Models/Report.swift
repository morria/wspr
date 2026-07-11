import Foundation
import CoreLocation

/// A single WSPR reception report ("spot"): one station heard another at a moment in time.
///
/// In WSPR terminology the *transmitter* (`tx`) is the station being heard, and the
/// *reporter* / *receiver* (`rx`) is the station doing the hearing.
struct Report: Identifiable, Hashable, Codable {
    var id: String
    var timestamp: Date

    // Transmitting (heard) station.
    var txCallsign: String
    var txGrid: String
    var txLatitude: Double?
    var txLongitude: Double?

    // Receiving (reporting) station.
    var rxCallsign: String
    var rxGrid: String
    var rxLatitude: Double?
    var rxLongitude: Double?

    var frequencyHz: Double
    var powerDBm: Int
    var snr: Int
    var drift: Int
    var distanceKm: Double?
    var azimuth: Double?

    var source: SpotSource

    var band: Band? { Band.band(forFrequencyHz: frequencyHz) }

    /// Coordinate of the transmitting station, resolving from grid if lat/lon are absent.
    var txCoordinate: CLLocationCoordinate2D? {
        if let lat = txLatitude, let lon = txLongitude, !(lat == 0 && lon == 0) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return MaidenheadLocator.coordinate(from: txGrid)
    }

    /// Coordinate of the receiving station, resolving from grid if lat/lon are absent.
    var rxCoordinate: CLLocationCoordinate2D? {
        if let lat = rxLatitude, let lon = rxLongitude, !(lat == 0 && lon == 0) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return MaidenheadLocator.coordinate(from: rxGrid)
    }

    /// The coordinate used to plot this report on the map (the heard/transmitting station).
    var mapCoordinate: CLLocationCoordinate2D? { txCoordinate }
}
