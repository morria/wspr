import Foundation
import AVFoundation
import Observation

/// Captures audio from the device input (radio connected to the mic/line-in), slices it
/// into 2-minute WSPR windows aligned to even UTC minutes, and hands each window to a
/// `WSPRDecoder`. Decoded frames are surfaced as `.radio`-source reports.
///
/// The audio path is real; the bundled decoder is a stub (see `NullWSPRDecoder`), so
/// no spots are produced until a full decoder is supplied. Receiving is opt-in.
@MainActor
@Observable
final class ReceiveController {

    private(set) var isListening = false
    private(set) var statusText = "Idle"
    private(set) var lastError: String?
    /// Reports decoded locally this session.
    private(set) var localReports: [Report] = []

    /// Called whenever new local reports are decoded.
    var onNewReports: (([Report]) -> Void)?

    /// The station identity used to stamp decoded spots as "heard by me".
    var myCallsign: String = ""
    var myGrid: String = ""

    private let engine = AVAudioEngine()
    private var decoder: WSPRDecoder = NullWSPRDecoder()

    private var slotSamples: [Float] = []
    private var slotStart: Date?
    private var slotSampleRate: Double = 48_000

    func start() {
        guard !isListening else { return }
        Task { await requestPermissionAndStart() }
    }

    func stop() {
        isListening = false
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        slotSamples.removeAll()
        slotStart = nil
        statusText = "Idle"
    }

    func toggle() { isListening ? stop() : start() }

    private func requestPermissionAndStart() async {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else {
            lastError = "Microphone access is needed to receive WSPR audio. Enable it in Settings."
            return
        }
        do {
            try beginCapture()
            isListening = true
            lastError = nil
            statusText = "Listening…"
        } catch {
            lastError = "Couldn't start listening: \(error.localizedDescription)"
        }
    }

    private func beginCapture() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        slotSampleRate = format.sampleRate

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            let chunk = Array(UnsafeBufferPointer(start: data, count: frames))
            Task { @MainActor in self.ingest(chunk) }
        }

        engine.prepare()
        try engine.start()
    }

    /// Accumulate samples, closing out a window when the even-minute boundary rolls over.
    private func ingest(_ chunk: [Float]) {
        let now = Date()
        let currentSlot = slotBoundary(for: now)

        if slotStart == nil { slotStart = currentSlot }

        if let start = slotStart, currentSlot > start {
            let finished = slotSamples
            let finishedStart = start
            slotSamples = []
            slotStart = currentSlot
            finishWindow(samples: finished, start: finishedStart)
        }

        slotSamples.append(contentsOf: chunk)
        // Cap memory: keep at most ~130 s of audio per window.
        let maxSamples = Int(slotSampleRate * 130)
        if slotSamples.count > maxSamples {
            slotSamples.removeFirst(slotSamples.count - maxSamples)
        }
    }

    private func slotBoundary(for date: Date) -> Date {
        let t = date.timeIntervalSince1970
        let base = (t / WSPRProtocolConstants.slotPeriod).rounded(.down) * WSPRProtocolConstants.slotPeriod
        return Date(timeIntervalSince1970: base)
    }

    private func finishWindow(samples: [Float], start: Date) {
        guard !samples.isEmpty else { return }
        let call = myCallsign
        let grid = myGrid

        // The bundled decoder is a fast stub; a real decoder can dispatch its own work.
        let decodes = decoder.decode(samples: samples, sampleRate: slotSampleRate)
        guard !decodes.isEmpty else { return }

        let reports = decodes.map { d in
            Report(id: "radio-\(start.timeIntervalSince1970)-\(d.callsign)-\(d.frequencyHz)",
                   timestamp: start,
                   txCallsign: d.callsign,
                   txGrid: d.grid,
                   txLatitude: nil, txLongitude: nil,
                   rxCallsign: call, rxGrid: grid,
                   rxLatitude: nil, rxLongitude: nil,
                   frequencyHz: d.frequencyHz,
                   powerDBm: d.powerDBm,
                   snr: d.snr,
                   drift: d.drift,
                   distanceKm: MaidenheadLocator.distanceKm(from: grid, to: d.grid),
                   azimuth: nil,
                   source: .radio)
        }
        localReports.append(contentsOf: reports)
        onNewReports?(reports)
    }
}
