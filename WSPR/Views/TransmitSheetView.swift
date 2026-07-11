import SwiftUI

/// The transmit console, presented as a hideable bottom sheet over the map/list.
/// Toggling on begins the continuous WSPR cycle: wait for the next even-minute slot,
/// key the radio via audio for ~110 seconds, repeat.
struct TransmitSheetView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(TransmitController.self) private var transmitter
    @Environment(ReceiveController.self) private var receiver
    @Environment(\.dismiss) private var dismiss

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if settings.isStationConfigured {
                        stationCard
                        statusDisplay
                        transmitButton
                        if let error = transmitter.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }
                        infoNote
                        Divider()
                        receiveSection
                    } else {
                        notConfigured
                    }
                }
                .padding()
            }
            .navigationTitle("Transmit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hide") { dismiss() }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: - Station

    private var stationCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.callsign.uppercased())
                    .font(.title2.weight(.bold))
                    .monospaced()
                Text(settings.gridSquare.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.txBand.name)
                    .font(.headline)
                    .foregroundStyle(settings.txBand.color)
                Text(WSPRPower.wattsLabel(dBm: settings.txPowerDBm))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Status ring

    private var statusDisplay: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: ringProgress)

            VStack(spacing: 4) {
                Text(primaryStatus)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(secondaryStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if transmitter.transmissionCount > 0 {
                    Text("^[\(transmitter.transmissionCount) frame](inflect: true) sent")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 220, height: 220)
        .padding(.vertical, 8)
    }

    private var ringProgress: Double {
        switch transmitter.phase {
        case .transmitting: return transmitter.progress
        case .waiting:
            // Fill as the slot approaches (0…120 s window).
            let remaining = Double(transmitter.secondsUntilNextTransmission)
            return max(0, min(1, (120 - remaining) / 120))
        case .idle: return 0
        }
    }

    private var ringColor: Color {
        switch transmitter.phase {
        case .transmitting: return .green
        case .waiting: return .accentColor
        case .idle: return .secondary
        }
    }

    private var primaryStatus: String {
        guard transmitter.isEnabled else { return "Ready" }
        switch transmitter.phase {
        case .idle: return "Ready"
        case .waiting: return timeString(transmitter.secondsUntilNextTransmission)
        case .transmitting: return timeString(transmitter.secondsRemaining)
        }
    }

    private var secondaryStatus: String {
        guard transmitter.isEnabled else { return "Tap transmit to begin" }
        switch transmitter.phase {
        case .idle: return "Starting…"
        case .waiting: return "until next transmission"
        case .transmitting: return "on air"
        }
    }

    // MARK: - Toggle

    private var transmitButton: some View {
        Button {
            transmitter.toggle(config: settings.transmitConfig)
        } label: {
            Label(transmitter.isEnabled ? "Stop Transmitting" : "Start Transmitting",
                  systemImage: transmitter.isEnabled ? "stop.fill" : "dot.radiowaves.left.and.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(transmitter.isEnabled ? .red : .accentColor)
        .controlSize(.large)
    }

    private var infoNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connect this device's audio output to your radio's mic input and enable VOX.",
                  systemImage: "cable.connector")
            Label("Transmits ~110 s starting on each even UTC minute. Keep the app in the foreground or connected to power for long runs.",
                  systemImage: "clock")
            Label("Tune your radio to \(settings.txBand.name): dial \(String(format: "%.6f", settings.txBand.dialMHz)) MHz USB.",
                  systemImage: "antenna.radiowaves.left.and.right")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Receive

    private var receiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { receiver.isListening },
                set: { on in
                    receiver.myCallsign = settings.callsign
                    receiver.myGrid = settings.gridSquare
                    on ? receiver.start() : receiver.stop()
                }
            )) {
                Label("Listen on radio", systemImage: "waveform.badge.mic")
            }
            Text(receiver.isListening ? receiver.statusText
                 : "Decode WSPR from your radio's audio via the microphone. Experimental — captured audio is windowed but the decoder is a stub.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = receiver.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Not configured

    private var notConfigured: some View {
        ContentUnavailableView {
            Label("Set Up Your Station", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("Add your callsign and grid locator before transmitting.")
        } actions: {
            Button("Open Settings") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
