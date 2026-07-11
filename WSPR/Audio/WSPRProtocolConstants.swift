import Foundation

/// Fixed timing/modulation constants for the WSPR protocol.
enum WSPRProtocolConstants {
    /// Number of channel symbols in a transmission.
    static let symbolCount = 162

    /// Length of one symbol in seconds: 8192 / 12000 ≈ 0.6827 s.
    static let symbolLength: Double = 8192.0 / 12000.0

    /// Spacing between the four FSK tones in Hz: 12000 / 8192 ≈ 1.4648 Hz.
    static let toneSpacing: Double = 12000.0 / 8192.0

    /// Total on-air duration of a transmission (≈ 110.6 s).
    static var transmissionDuration: Double { Double(symbolCount) * symbolLength }

    /// WSPR slots begin one second into an even UTC minute; slots repeat every 120 s.
    static let slotPeriod: Double = 120.0
    static let slotStartOffset: Double = 1.0

    /// Default audio sub-carrier that lands the signal in the middle of the passband
    /// (dial + 1500 Hz) when the radio is in USB. This is the tone your radio hears.
    static let defaultAudioBaseFrequency: Double = 1500.0

    /// The next WSPR slot start time at or after `date`, requiring at least `minLead`
    /// seconds of lead time to prepare audio.
    static func nextSlotStart(after date: Date, minLead: Double = 2.0) -> Date {
        let t = date.timeIntervalSince1970
        let base = (t / slotPeriod).rounded(.down) * slotPeriod
        var start = base + slotStartOffset
        while start <= t + minLead { start += slotPeriod }
        return Date(timeIntervalSince1970: start)
    }
}
