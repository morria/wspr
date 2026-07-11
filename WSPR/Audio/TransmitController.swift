import Foundation
import AVFoundation
import Observation

/// Configuration for a transmit session, snapshotted from Settings when the user toggles on.
struct TransmitConfig: Equatable {
    var callsign: String
    var grid: String
    var powerDBm: Int
    var band: Band
    var audioBaseFrequency: Double
}

/// Drives the continuous WSPR transmit cycle: wait for the next even-minute slot,
/// play the ~110.6 s frame out of the audio output, then repeat while enabled.
@MainActor
@Observable
final class TransmitController {

    enum Phase: Equatable {
        case idle
        case waiting          // counting down to the next slot
        case transmitting     // frame is on the air
    }

    private(set) var isEnabled = false
    private(set) var phase: Phase = .idle

    /// Seconds until the next slot begins (valid while `.waiting`).
    private(set) var secondsUntilNextTransmission: Int = 0
    /// Seconds remaining in the current frame (valid while `.transmitting`).
    private(set) var secondsRemaining: Int = 0
    /// 0…1 progress of the current frame.
    private(set) var progress: Double = 0
    /// Count of frames sent this session.
    private(set) var transmissionCount = 0
    private(set) var lastError: String?

    var config: TransmitConfig?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var loopTask: Task<Void, Never>?

    init() {
        engine.attach(player)
    }

    // MARK: - Control

    func start(config: TransmitConfig) {
        // Validate up-front so we never toggle on with an un-encodable message.
        do {
            _ = try WSPRMessage.encode(callsign: config.callsign,
                                       grid: config.grid,
                                       powerDBm: config.powerDBm)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }

        lastError = nil
        self.config = config
        isEnabled = true
        transmissionCount = 0
        loopTask?.cancel()
        loopTask = Task { await runLoop() }
    }

    func stop() {
        isEnabled = false
        loopTask?.cancel()
        loopTask = nil
        stopAudio()
        phase = .idle
        progress = 0
        secondsRemaining = 0
        secondsUntilNextTransmission = 0
    }

    func toggle(config: TransmitConfig) {
        if isEnabled { stop() } else { start(config: config) }
    }

    // MARK: - Loop

    private func runLoop() async {
        while isEnabled && !Task.isCancelled {
            let slotStart = WSPRProtocolConstants.nextSlotStart(after: Date())

            // Countdown to the slot.
            phase = .waiting
            while isEnabled && !Task.isCancelled {
                let remaining = slotStart.timeIntervalSinceNow
                if remaining <= 0 { break }
                secondsUntilNextTransmission = Int(remaining.rounded(.up))
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard isEnabled, !Task.isCancelled, let config else { break }

            await transmitFrame(config: config, startedAt: slotStart)
        }
        if !isEnabled { phase = .idle }
    }

    private func transmitFrame(config: TransmitConfig, startedAt: Date) async {
        guard let symbols = try? WSPRMessage.encode(callsign: config.callsign,
                                                    grid: config.grid,
                                                    powerDBm: config.powerDBm) else { return }

        // Build the waveform off the main actor to keep the UI fluid.
        let base = config.audioBaseFrequency
        let buffer = await Task.detached(priority: .userInitiated) {
            WSPRToneSynth.makeBuffer(symbols: symbols, baseFrequency: base)
        }.value
        guard let buffer else { return }

        do {
            try configureAudioSessionForPlayback()
            // Connect using the buffer's format so scheduling never hits a format mismatch.
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            if !engine.isRunning { try engine.start() }
        } catch {
            lastError = "Audio couldn't start: \(error.localizedDescription)"
            return
        }

        phase = .transmitting
        transmissionCount += 1
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in }
        player.play()

        let duration = WSPRProtocolConstants.transmissionDuration
        let endTime = Date().addingTimeInterval(duration)
        while isEnabled && !Task.isCancelled {
            let remaining = endTime.timeIntervalSinceNow
            if remaining <= 0 { break }
            secondsRemaining = Int(remaining.rounded(.up))
            progress = max(0, min(1, (duration - remaining) / duration))
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        stopAudio()
        progress = 0
        secondsRemaining = 0
    }

    // MARK: - Audio session

    private func configureAudioSessionForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: [])
    }

    private func stopAudio() {
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
