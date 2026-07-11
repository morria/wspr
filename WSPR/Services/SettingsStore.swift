import Foundation
import Observation

/// Persistent user settings: station identity and transmit defaults.
@MainActor
@Observable
final class SettingsStore {
    private let defaults = UserDefaults.standard

    var callsign: String { didSet { defaults.set(callsign, forKey: Keys.callsign) } }
    var gridSquare: String { didSet { defaults.set(gridSquare, forKey: Keys.grid) } }
    var txPowerDBm: Int { didSet { defaults.set(txPowerDBm, forKey: Keys.power) } }
    var txBandDial: Int { didSet { defaults.set(txBandDial, forKey: Keys.band) } }
    var audioBaseFrequency: Double { didSet { defaults.set(audioBaseFrequency, forKey: Keys.audioFreq) } }
    /// Keep the grid square updated automatically from the device location.
    var followLocation: Bool { didSet { defaults.set(followLocation, forKey: Keys.followLocation) } }

    var txBand: Band {
        get { Band.all.first { $0.dialFrequency == txBandDial } ?? .twentyMeters }
        set { txBandDial = newValue.dialFrequency }
    }

    var isStationConfigured: Bool {
        !callsign.trimmingCharacters(in: .whitespaces).isEmpty &&
        MaidenheadLocator.isValid(gridSquare)
    }

    var transmitConfig: TransmitConfig {
        TransmitConfig(callsign: callsign,
                       grid: gridSquare,
                       powerDBm: txPowerDBm,
                       band: txBand,
                       audioBaseFrequency: audioBaseFrequency)
    }

    init() {
        callsign = defaults.string(forKey: Keys.callsign) ?? ""
        gridSquare = defaults.string(forKey: Keys.grid) ?? ""
        txPowerDBm = defaults.object(forKey: Keys.power) as? Int ?? 37
        txBandDial = defaults.object(forKey: Keys.band) as? Int ?? Band.twentyMeters.dialFrequency
        audioBaseFrequency = defaults.object(forKey: Keys.audioFreq) as? Double
            ?? WSPRProtocolConstants.defaultAudioBaseFrequency
        followLocation = defaults.object(forKey: Keys.followLocation) as? Bool ?? false
    }

    private enum Keys {
        static let callsign = "settings.callsign"
        static let grid = "settings.grid"
        static let power = "settings.powerDBm"
        static let band = "settings.bandDial"
        static let audioFreq = "settings.audioBaseFrequency"
        static let followLocation = "settings.followLocation"
    }
}
