import Foundation
import CoreLocation

/// A relative or absolute time window over which to show reports.
enum TimeWindow: Hashable, Codable {
    /// The most recent `minutes` minutes.
    case minutes(Int)
    /// An explicit start/end range.
    case range(start: Date, end: Date)

    /// The preset "last N minutes" windows offered in the UI (doubling from 4 minutes).
    static let presets: [Int] = [4, 8, 16, 32, 64, 128, 360, 720, 1440]

    var label: String {
        switch self {
        case .minutes(let m):
            if m < 60 { return "\(m) min" }
            if m % 60 == 0 {
                let h = m / 60
                return h == 1 ? "1 hour" : "\(h) hours"
            }
            return "\(m) min"
        case .range:
            return "Custom range"
        }
    }

    /// The earliest instant included by this window, relative to `now`.
    func earliest(now: Date) -> Date {
        switch self {
        case .minutes(let m): return now.addingTimeInterval(-Double(m) * 60)
        case .range(let start, _): return start
        }
    }

    func latest(now: Date) -> Date {
        switch self {
        case .minutes: return now
        case .range(_, let end): return end
        }
    }

    /// Whole minutes of look-back, used to bound network queries.
    func lookbackMinutes(now: Date) -> Int {
        switch self {
        case .minutes(let m): return m
        case .range(let start, let end):
            return max(1, Int(end.timeIntervalSince(start) / 60))
        }
    }
}

/// The point that a radius filter is measured from.
enum RadiusCenter: Hashable, Codable {
    case myStation
    case grid(String)
    case coordinate(latitude: Double, longitude: Double, label: String)

    var label: String {
        switch self {
        case .myStation: return "My station"
        case .grid(let g): return g.uppercased()
        case .coordinate(_, _, let label): return label
        }
    }

    func coordinate(myCoordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        switch self {
        case .myStation: return myCoordinate
        case .grid(let g): return MaidenheadLocator.coordinate(from: g)
        case .coordinate(let lat, let lon, _): return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

/// The complete set of user-controllable filters over the reports list/map.
struct ReportFilter: Hashable, Codable {
    /// Radio-only, internet-only, or both.
    var source: SourceFilter = .both
    /// When on, show only spots of *my* station being heard by others.
    var onlyStationsHearingMe: Bool = false
    /// Time window.
    var timeWindow: TimeWindow = .minutes(32)
    /// Optional band restriction (nil = all bands).
    var band: Band? = nil

    /// Whether the radius filter is active.
    var radiusEnabled: Bool = false
    var radiusCenter: RadiusCenter = .myStation
    var radiusKm: Double = 500

    /// True if this is the default, untouched filter (used to badge the filter button).
    var isDefault: Bool {
        self == ReportFilter()
    }

    /// Client-side predicate. `myCallsign` and `myCoordinate` supply "my station" context.
    func matches(_ report: Report, now: Date, myCallsign: String, myCoordinate: CLLocationCoordinate2D?) -> Bool {
        guard source.includes(report.source) else { return false }

        if report.timestamp < timeWindow.earliest(now: now) { return false }
        if report.timestamp > timeWindow.latest(now: now).addingTimeInterval(120) { return false }

        if let band, report.band?.id != band.id { return false }

        if onlyStationsHearingMe {
            let mine = myCallsign.trimmingCharacters(in: .whitespaces).uppercased()
            guard !mine.isEmpty, report.txCallsign.uppercased() == mine else { return false }
        }

        if radiusEnabled {
            guard let center = radiusCenter.coordinate(myCoordinate: myCoordinate),
                  let point = report.mapCoordinate else { return false }
            let a = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let b = CLLocation(latitude: point.latitude, longitude: point.longitude)
            if a.distance(from: b) / 1000.0 > radiusKm { return false }
        }

        return true
    }
}
