import Foundation

/// Helpers for WSPR transmit power, which is reported in dBm (decibels relative to 1 mW).
enum WSPRPower {
    /// The 28 power levels the WSPR protocol can encode.
    static let validDBm: [Int] = [
        -30, -27, -23, -20, -17, -13, -10, -7, -3,
        0, 3, 7, 10, 13, 17, 20, 23, 27, 30, 33, 37, 40,
        43, 47, 50, 53, 57, 60
    ]

    /// The nearest legal WSPR power at or below `dBm`.
    static func nearestValid(_ dBm: Int) -> Int {
        if dBm <= validDBm.first! { return validDBm.first! }
        if dBm >= validDBm.last! { return validDBm.last! }
        var best = validDBm.first!
        for value in validDBm where value <= dBm { best = value }
        return best
    }

    /// Convert dBm to watts.
    static func watts(fromDBm dBm: Int) -> Double {
        pow(10.0, Double(dBm) / 10.0) / 1000.0
    }

    /// A short human label, e.g. "37 dBm · 5 W".
    static func label(dBm: Int) -> String {
        "\(dBm) dBm · \(wattsLabel(dBm: dBm))"
    }

    static func wattsLabel(dBm: Int) -> String {
        let w = watts(fromDBm: dBm)
        if w >= 1 {
            return w == w.rounded() ? "\(Int(w)) W" : String(format: "%.1f W", w)
        } else if w >= 0.001 {
            return String(format: "%.0f mW", w * 1000)
        } else {
            return String(format: "%.2f mW", w * 1000)
        }
    }
}
