import Foundation

/// A WSPR amateur band, identified by its standard USB dial frequency.
///
/// WSPR signals occupy a 200 Hz window from `dial + 1400 Hz` to `dial + 1600 Hz`.
/// The reception reports returned by the network store the absolute RF frequency in Hz,
/// so we filter by that window rather than by a band code.
struct Band: Identifiable, Hashable, Codable {
    let name: String          // e.g. "20m"
    let dialFrequency: Int    // USB dial frequency in Hz
    let wsprnetCode: Int      // WSPRnet integer band code (used for display/interop)

    var id: Int { dialFrequency }

    /// Lower edge of the WSPR passband in Hz.
    var passbandLow: Int { dialFrequency + 1400 }
    /// Upper edge of the WSPR passband in Hz.
    var passbandHigh: Int { dialFrequency + 1600 }

    var dialMHz: Double { Double(dialFrequency) / 1_000_000.0 }

    /// The standard WSPR bands, low to high.
    static let all: [Band] = [
        Band(name: "2200m", dialFrequency: 136_000,     wsprnetCode: -1),
        Band(name: "630m",  dialFrequency: 474_200,     wsprnetCode: 0),
        Band(name: "160m",  dialFrequency: 1_836_600,   wsprnetCode: 1),
        Band(name: "80m",   dialFrequency: 3_568_600,   wsprnetCode: 3),
        Band(name: "60m",   dialFrequency: 5_287_200,   wsprnetCode: 5),
        Band(name: "40m",   dialFrequency: 7_038_600,   wsprnetCode: 7),
        Band(name: "30m",   dialFrequency: 10_138_700,  wsprnetCode: 10),
        Band(name: "20m",   dialFrequency: 14_095_600,  wsprnetCode: 14),
        Band(name: "17m",   dialFrequency: 18_104_600,  wsprnetCode: 18),
        Band(name: "15m",   dialFrequency: 21_094_600,  wsprnetCode: 21),
        Band(name: "12m",   dialFrequency: 24_924_600,  wsprnetCode: 24),
        Band(name: "10m",   dialFrequency: 28_124_600,  wsprnetCode: 28),
        Band(name: "6m",    dialFrequency: 50_293_000,  wsprnetCode: 50),
        Band(name: "2m",    dialFrequency: 144_489_000, wsprnetCode: 144),
    ]

    /// The band whose passband contains the given absolute RF frequency (Hz), if any.
    static func band(forFrequencyHz hz: Double) -> Band? {
        all.first { Double($0.passbandLow) - 100 <= hz && hz <= Double($0.passbandHigh) + 100 }
    }

    static let twentyMeters = all.first { $0.name == "20m" }!
}
