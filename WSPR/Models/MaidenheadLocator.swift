import Foundation
import CoreLocation

/// Utilities for converting between Maidenhead grid squares and geographic coordinates.
///
/// WSPR reports use Maidenhead locators (e.g. `FN20`, `IO91wm`) to describe station
/// position. A 4-character locator resolves to the centre of a 2° × 1° square; a
/// 6-character locator refines that to a 5′ × 2.5′ subsquare.
enum MaidenheadLocator {

    /// Convert a coordinate into a Maidenhead locator of the requested length (4 or 6).
    static func gridSquare(from coordinate: CLLocationCoordinate2D, length: Int = 6) -> String {
        var lon = coordinate.longitude + 180.0
        var lat = coordinate.latitude + 90.0

        let A = UnicodeScalar("A").value
        let zero = UnicodeScalar("0").value

        // Field: 20° lon, 10° lat.
        let lonField = Int(lon / 20.0)
        let latField = Int(lat / 10.0)
        lon -= Double(lonField) * 20.0
        lat -= Double(latField) * 10.0

        // Square: 2° lon, 1° lat.
        let lonSquare = Int(lon / 2.0)
        let latSquare = Int(lat / 1.0)
        lon -= Double(lonSquare) * 2.0
        lat -= Double(latSquare) * 1.0

        var result = ""
        result.unicodeScalars.append(UnicodeScalar(A + UInt32(min(17, max(0, lonField))))!)
        result.unicodeScalars.append(UnicodeScalar(A + UInt32(min(17, max(0, latField))))!)
        result.unicodeScalars.append(UnicodeScalar(zero + UInt32(lonSquare))!)
        result.unicodeScalars.append(UnicodeScalar(zero + UInt32(latSquare))!)

        if length >= 6 {
            // Subsquare: 5′ (1/12°... i.e. 2°/24) lon, 2.5′ lat.
            let lonSub = Int(lon / (2.0 / 24.0))
            let latSub = Int(lat / (1.0 / 24.0))
            result.unicodeScalars.append(UnicodeScalar(A + UInt32(min(23, max(0, lonSub))))!)
            result.unicodeScalars.append(UnicodeScalar(A + UInt32(min(23, max(0, latSub))))!)
        }
        return result
    }

    /// Convert a Maidenhead locator to the coordinate at the centre of its square/subsquare.
    /// Returns `nil` if the string is not a valid 4- or 6-character locator.
    static func coordinate(from locator: String) -> CLLocationCoordinate2D? {
        let g = locator.trimmingCharacters(in: .whitespaces).uppercased()
        let chars = Array(g.unicodeScalars)
        guard chars.count == 4 || chars.count == 6 else { return nil }

        func value(_ scalar: UnicodeScalar, base: UnicodeScalar) -> Int { Int(scalar.value) - Int(base.value) }
        let A = UnicodeScalar("A"), Z = UnicodeScalar("Z")
        let zero = UnicodeScalar("0"), nine = UnicodeScalar("9")

        guard chars[0] >= A, chars[0] <= UnicodeScalar("R"),
              chars[1] >= A, chars[1] <= UnicodeScalar("R"),
              chars[2] >= zero, chars[2] <= nine,
              chars[3] >= zero, chars[3] <= nine else { return nil }

        var lon = Double(value(chars[0], base: A)) * 20.0
        var lat = Double(value(chars[1], base: A)) * 10.0
        lon += Double(value(chars[2], base: zero)) * 2.0
        lat += Double(value(chars[3], base: zero)) * 1.0

        if chars.count == 6 {
            let upper = UnicodeScalar("X")
            guard chars[4] >= A, chars[4] <= upper, chars[5] >= A, chars[5] <= upper else { return nil }
            lon += (Double(value(chars[4], base: A)) + 0.5) * (2.0 / 24.0)
            lat += (Double(value(chars[5], base: A)) + 0.5) * (1.0 / 24.0)
            _ = Z
        } else {
            // Centre of the 2° × 1° square.
            lon += 1.0
            lat += 0.5
        }

        return CLLocationCoordinate2D(latitude: lat - 90.0, longitude: lon - 180.0)
    }

    /// Great-circle distance in kilometres between two locators.
    static func distanceKm(from a: String, to b: String) -> Double? {
        guard let ca = coordinate(from: a), let cb = coordinate(from: b) else { return nil }
        let la = CLLocation(latitude: ca.latitude, longitude: ca.longitude)
        let lb = CLLocation(latitude: cb.latitude, longitude: cb.longitude)
        return la.distance(from: lb) / 1000.0
    }

    /// Validate a 4- or 6-character locator.
    static func isValid(_ locator: String) -> Bool {
        coordinate(from: locator) != nil
    }
}
