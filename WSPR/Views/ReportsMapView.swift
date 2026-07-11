import SwiftUI
import MapKit

/// A map of WSPR reports. Each heard (transmitting) station is a band-coloured dot;
/// tapping one opens its detail. The user's station and any active radius are overlaid.
struct ReportsMapView: View {
    @Environment(ReportsStore.self) private var reports
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationManager.self) private var location

    @Binding var selectedReport: Report?
    @State private var camera: MapCameraPosition = .automatic

    /// Cap plotted markers so dense result sets stay smooth.
    private let markerLimit = 400

    private var plotted: [Report] {
        Array(reports.filteredReports.prefix(markerLimit))
    }

    private var myCoordinate: CLLocationCoordinate2D? {
        location.coordinate ?? MaidenheadLocator.coordinate(from: settings.gridSquare)
    }

    private var radiusCenter: CLLocationCoordinate2D? {
        guard reports.filter.radiusEnabled else { return nil }
        return reports.filter.radiusCenter.coordinate(myCoordinate: myCoordinate)
    }

    var body: some View {
        Map(position: $camera) {
            if let center = radiusCenter {
                MapCircle(center: center, radius: reports.filter.radiusKm * 1000)
                    .foregroundStyle(Color.accentColor.opacity(0.10))
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
            }

            ForEach(plotted) { report in
                if let coordinate = report.mapCoordinate {
                    Annotation(report.txCallsign, coordinate: coordinate) {
                        ReportMarker(report: report,
                                     isMine: isMine(report))
                            .onTapGesture { selectedReport = report }
                    }
                    .annotationTitles(.hidden)
                }
            }

            if let me = myCoordinate {
                Marker("My station", systemImage: "house.fill", coordinate: me)
                    .tint(.accentColor)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .topTrailing) {
            MapLegend()
                .padding(8)
        }
        .safeAreaInset(edge: .bottom) {
            if !plotted.isEmpty {
                Text("\(reports.filteredReports.count) reports" +
                     (reports.filteredReports.count > markerLimit ? " · showing \(markerLimit)" : ""))
                    .font(.caption)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 4)
            }
        }
    }

    private func isMine(_ report: Report) -> Bool {
        let mine = settings.callsign.trimmingCharacters(in: .whitespaces).uppercased()
        return !mine.isEmpty && report.txCallsign.uppercased() == mine
    }
}

private struct ReportMarker: View {
    let report: Report
    let isMine: Bool

    var body: some View {
        Circle()
            .fill(report.bandColor)
            .stroke(isMine ? Color.primary : .white, lineWidth: isMine ? 2 : 1)
            .frame(width: isMine ? 16 : 12, height: isMine ? 16 : 12)
            .shadow(radius: 1)
    }
}

private struct MapLegend: View {
    @Environment(ReportsStore.self) private var reports

    private var bandsShown: [Band] {
        var seen = Set<Int>()
        var result: [Band] = []
        for report in reports.filteredReports.prefix(400) {
            if let band = report.band, !seen.contains(band.id) {
                seen.insert(band.id)
                result.append(band)
            }
        }
        return result.sorted { $0.dialFrequency < $1.dialFrequency }
    }

    var body: some View {
        if !bandsShown.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(bandsShown.prefix(8)) { band in
                    HStack(spacing: 6) {
                        Circle().fill(band.color).frame(width: 8, height: 8)
                        Text(band.name).font(.caption2)
                    }
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
