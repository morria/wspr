import Foundation
import AVFoundation

/// Renders WSPR symbols into a continuous-phase 4-FSK audio buffer suitable for
/// playing out of the device speaker / headphone jack into a VOX-keyed radio.
enum WSPRToneSynth {

    static let sampleRate: Double = 48_000.0

    /// Build a mono Float32 PCM buffer for the given symbols.
    /// - Parameters:
    ///   - symbols: 162 channel symbols (0–3).
    ///   - baseFrequency: audio frequency of tone 0, in Hz.
    ///   - amplitude: peak amplitude (0–1).
    static func makeBuffer(symbols: [UInt8],
                           baseFrequency: Double = WSPRProtocolConstants.defaultAudioBaseFrequency,
                           amplitude: Float = 0.7) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false) else { return nil }

        let symbolLength = WSPRProtocolConstants.symbolLength
        let toneSpacing = WSPRProtocolConstants.toneSpacing
        let totalSamples = Int((symbolLength * Double(symbols.count) * sampleRate).rounded())

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(totalSamples)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        // Short raised-cosine fades to suppress key clicks.
        let fadeSamples = Int(0.02 * sampleRate)

        var phase = 0.0
        let twoPi = 2.0 * Double.pi
        for n in 0..<totalSamples {
            let t = Double(n) / sampleRate
            let symbolIndex = min(symbols.count - 1, Int(t / symbolLength))
            let freq = baseFrequency + Double(symbols[symbolIndex]) * toneSpacing
            phase += twoPi * freq / sampleRate
            if phase > twoPi { phase -= twoPi }

            var env: Double = 1.0
            if n < fadeSamples {
                env = 0.5 * (1 - cos(Double.pi * Double(n) / Double(fadeSamples)))
            } else if n > totalSamples - fadeSamples {
                let k = totalSamples - n
                env = 0.5 * (1 - cos(Double.pi * Double(k) / Double(fadeSamples)))
            }
            channel[n] = Float(sin(phase) * env) * amplitude
        }
        return buffer
    }
}
