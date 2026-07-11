import SwiftUI

/// Station identity and transmit defaults.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationManager.self) private var location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    TextField("Callsign", text: $settings.callsign)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } header: {
                    Text("Station")
                } footer: {
                    Text("Your amateur radio callsign. Compound calls (with “/”) can be shown but not transmitted yet.")
                }

                Section {
                    HStack {
                        TextField("Grid locator (e.g. FN20)", text: $settings.gridSquare)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                        if MaidenheadLocator.isValid(settings.gridSquare) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if !settings.gridSquare.isEmpty {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        }
                    }
                    Button {
                        location.requestPermission()
                        location.requestLocation()
                        if let grid = location.gridSquare { settings.gridSquare = grid }
                    } label: {
                        Label("Use current location", systemImage: "location")
                    }
                    Toggle("Keep grid updated from location", isOn: $settings.followLocation)
                } header: {
                    Text("Location")
                } footer: {
                    Text("A 6-character Maidenhead locator gives the most accurate map placement.")
                }

                Section("Transmit Defaults") {
                    Picker("Band", selection: $settings.txBandDial) {
                        ForEach(Band.all) { band in
                            Text("\(band.name) · \(String(format: "%.3f", band.dialMHz)) MHz").tag(band.dialFrequency)
                        }
                    }
                    Picker("Power", selection: $settings.txPowerDBm) {
                        ForEach(WSPRPower.validDBm, id: \.self) { dBm in
                            Text(WSPRPower.label(dBm: dBm)).tag(dBm)
                        }
                    }
                    Stepper(value: $settings.audioBaseFrequency, in: 1400...1600, step: 10) {
                        LabeledContent("Audio tone", value: "\(Int(settings.audioBaseFrequency)) Hz")
                    }
                }

                Section {
                    LabeledContent("Protocol", value: "WSPR · 2 min · 6 Hz")
                    LabeledContent("Data", value: "wspr.live (WSPRnet)")
                } header: {
                    Text("About")
                } footer: {
                    Text("WSPR (Weak Signal Propagation Reporter) was created by Joe Taylor, K1JT. Transmit encoding follows the WSJT-X / JTEncode implementation. Report data is provided by the WSPRnet community via wspr.live.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
