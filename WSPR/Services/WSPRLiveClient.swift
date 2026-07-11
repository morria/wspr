import Foundation
import CoreLocation

/// Client for the public **wspr.live** database (a ClickHouse instance holding the
/// global WSPRnet spot archive). Queries are plain SQL against `wspr.rx` sent over
/// the HTTP interface, per <https://wspr.live>.
///
/// Per wspr.live's usage guidance every query is bounded by time (and band where
/// possible) and scoped to the user's station or a geographic region so we never
/// pull more of the global feed than we need.
struct WSPRLiveClient {

    enum ClientError: Error, LocalizedError {
        case badResponse
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse: return "Unexpected response from wspr.live."
            case .http(let code): return "wspr.live returned HTTP \(code)."
            }
        }
    }

    private let endpoint = URL(string: "https://db1.wspr.live/")!
    private let rowLimit = 3000

    func fetchReports(filter: ReportFilter,
                      myCallsign: String,
                      myCoordinate: CLLocationCoordinate2D?,
                      now: Date = Date()) async throws -> [Report] {
        let sql = buildQuery(filter: filter, myCallsign: myCallsign, myCoordinate: myCoordinate, now: now)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: sql + " FORMAT JSON")]
        guard let url = components.url else { throw ClientError.badResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        guard (200...299).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }

        return parse(data: data)
    }

    // MARK: - Query building

    private func buildQuery(filter: ReportFilter,
                            myCallsign: String,
                            myCoordinate: CLLocationCoordinate2D?,
                            now: Date) -> String {
        var clauses: [String] = []

        let lookback = filter.timeWindow.lookbackMinutes(now: now)
        clauses.append("time >= subtractMinutes(now(), \(lookback))")

        if let band = filter.band {
            clauses.append("frequency >= \(band.passbandLow - 100) AND frequency <= \(band.passbandHigh + 100)")
        }

        let call = sanitizeCallsign(myCallsign)

        if filter.onlyStationsHearingMe, !call.isEmpty {
            clauses.append("tx_sign = '\(call)'")
        } else if filter.radiusEnabled, filter.radiusKm <= 1500,
                  let center = filter.radiusCenter.coordinate(myCoordinate: myCoordinate) {
            let fields = gridFieldPrefixes(around: center)
            if !fields.isEmpty {
                let list = fields.map { "'\($0)'" }.joined(separator: ",")
                clauses.append("(substring(tx_loc, 1, 2) IN (\(list)) OR substring(rx_loc, 1, 2) IN (\(list)))")
            }
        } else if !call.isEmpty, !filter.radiusEnabled {
            // Default scope: my station's activity — who heard me and who I heard.
            clauses.append("(tx_sign = '\(call)' OR rx_sign = '\(call)')")
        }

        let columns = "id, toString(time) AS time, band, rx_sign, rx_lat, rx_lon, rx_loc, " +
            "tx_sign, tx_lat, tx_lon, tx_loc, distance, azimuth, frequency, power, snr, drift"

        return "SELECT \(columns) FROM wspr.rx WHERE \(clauses.joined(separator: " AND ")) " +
            "ORDER BY time DESC LIMIT \(rowLimit)"
    }

    private func sanitizeCallsign(_ call: String) -> String {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/")
        return String(call.uppercased().filter { allowed.contains($0) })
    }

    /// The center grid field plus its eight neighbours (2-char prefixes), used to
    /// narrow a regional query. A field spans 20° longitude × 10° latitude.
    private func gridFieldPrefixes(around coordinate: CLLocationCoordinate2D) -> [String] {
        let lonField = Int((coordinate.longitude + 180.0) / 20.0)
        let latField = Int((coordinate.latitude + 90.0) / 10.0)
        var results: [String] = []
        let A = UnicodeScalar("A").value
        for dLon in -1...1 {
            for dLat in -1...1 {
                let lf = ((lonField + dLon) % 18 + 18) % 18   // wrap longitude 0…17
                let tf = latField + dLat
                guard tf >= 0, tf <= 17 else { continue }
                if let lon = UnicodeScalar(A + UInt32(lf)), let lat = UnicodeScalar(A + UInt32(tf)) {
                    results.append(String(lon) + String(lat))
                }
            }
        }
        return results
    }

    // MARK: - Parsing

    private func parse(data: Data) -> [Report] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["data"] as? [[String: Any]] else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return rows.compactMap { row -> Report? in
            guard let tx = asString(row["tx_sign"]), !tx.isEmpty,
                  let rx = asString(row["rx_sign"]) else { return nil }
            let timeString = asString(row["time"]) ?? ""
            let timestamp = formatter.date(from: timeString) ?? Date()

            return Report(
                id: asString(row["id"]) ?? "\(tx)-\(rx)-\(timeString)",
                timestamp: timestamp,
                txCallsign: tx,
                txGrid: asString(row["tx_loc"]) ?? "",
                txLatitude: asDouble(row["tx_lat"]),
                txLongitude: asDouble(row["tx_lon"]),
                rxCallsign: rx,
                rxGrid: asString(row["rx_loc"]) ?? "",
                rxLatitude: asDouble(row["rx_lat"]),
                rxLongitude: asDouble(row["rx_lon"]),
                frequencyHz: asDouble(row["frequency"]) ?? 0,
                powerDBm: asInt(row["power"]) ?? 0,
                snr: asInt(row["snr"]) ?? 0,
                drift: asInt(row["drift"]) ?? 0,
                distanceKm: asDouble(row["distance"]),
                azimuth: asDouble(row["azimuth"]),
                source: .internet
            )
        }
    }

    private func asString(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    private func asDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func asInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }
}
