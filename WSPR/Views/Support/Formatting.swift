import SwiftUI

/// Presentation helpers shared across report views.
enum ReportFormatting {
    static func age(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    static func distance(_ km: Double?) -> String {
        guard let km else { return "—" }
        if km < 1 { return "<1 km" }
        return "\(Int(km.rounded())) km"
    }

    static func frequency(_ hz: Double) -> String {
        String(format: "%.6f MHz", hz / 1_000_000)
    }

    static func snr(_ value: Int) -> String {
        value >= 0 ? "+\(value) dB" : "\(value) dB"
    }

    static func azimuth(_ deg: Double?) -> String {
        guard let deg else { return "—" }
        return "\(Int(deg.rounded()))°"
    }
}

extension Band {
    /// A stable, evenly spread colour per band for map markers and list accents.
    var color: Color {
        let index = Band.all.firstIndex(where: { $0.id == id }) ?? 0
        let hue = Double(index) / Double(max(1, Band.all.count))
        return Color(hue: hue, saturation: 0.7, brightness: 0.9)
    }
}

extension Report {
    var bandColor: Color { band?.color ?? .gray }
    var bandName: String { band?.name ?? "—" }
}
