import SwiftUI
import MapKit

/// Detail for a single report: the propagation path on a map plus the full spot data.
struct ReportDetailView: View {
    let report: Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                pathMap
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
            }

            Section("Path") {
                LabeledContent("Transmitter", value: report.txCallsign)
                if !report.txGrid.isEmpty { LabeledContent("TX grid", value: report.txGrid) }
                LabeledContent("Reporter", value: report.rxCallsign)
                if !report.rxGrid.isEmpty { LabeledContent("RX grid", value: report.rxGrid) }
                LabeledContent("Distance", value: ReportFormatting.distance(report.distanceKm))
                LabeledContent("Bearing", value: ReportFormatting.azimuth(report.azimuth))
            }

            Section("Signal") {
                LabeledContent("Band", value: report.bandName)
                LabeledContent("Frequency", value: ReportFormatting.frequency(report.frequencyHz))
                LabeledContent("SNR", value: ReportFormatting.snr(report.snr))
                LabeledContent("Power", value: WSPRPower.label(dBm: report.powerDBm))
                LabeledContent("Drift", value: "\(report.drift) Hz")
            }

            Section("Report") {
                LabeledContent("Heard at", value: report.timestamp.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Source") {
                    Label(report.source.title, systemImage: report.source.systemImage)
                }
            }
        }
        .navigationTitle(report.txCallsign)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    @ViewBuilder private var pathMap: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            if let tx = report.txCoordinate {
                Marker(report.txCallsign, systemImage: "antenna.radiowaves.left.and.right", coordinate: tx)
                    .tint(report.bandColor)
            }
            if let rx = report.rxCoordinate {
                Marker(report.rxCallsign, systemImage: "ear", coordinate: rx)
                    .tint(.accentColor)
            }
            if let tx = report.txCoordinate, let rx = report.rxCoordinate {
                MapPolyline(coordinates: [tx, rx])
                    .stroke(report.bandColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }
}
