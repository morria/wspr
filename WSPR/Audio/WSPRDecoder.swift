import Foundation

/// A candidate WSPR decode produced from one 2-minute audio window.
struct DecodedSpot {
    var callsign: String
    var grid: String
    var powerDBm: Int
    var snr: Int
    var frequencyHz: Double
    var drift: Int
}

/// Decodes WSPR frames from a window of audio samples captured from the radio.
protocol WSPRDecoder {
    /// Decode a full 2-minute window (aligned to an even UTC minute).
    /// - Parameters:
    ///   - samples: mono Float samples for the window.
    ///   - sampleRate: sample rate of `samples`.
    func decode(samples: [Float], sampleRate: Double) -> [DecodedSpot]
}

/// Placeholder decoder.
///
/// A full WSPR receiver requires a synchronised FFT front-end plus a soft-decision
/// Fano sequential decoder for the K = 32 convolutional code (as in WSJT-X's
/// `wsprd`). That decoder is substantial and is deliberately **not** ported here —
/// the app captures and windows radio audio through the real pipeline, but this
/// stub returns no decodes. Drop in a real implementation to light up the "Radio"
/// source end-to-end.
struct NullWSPRDecoder: WSPRDecoder {
    func decode(samples: [Float], sampleRate: Double) -> [DecodedSpot] { [] }
}
