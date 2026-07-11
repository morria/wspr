import SwiftUI

/// A scrollable list of WSPR reports with pull-to-refresh and a summary header.
struct ReportsListView: View {
    @Environment(ReportsStore.self) private var reports
    @Environment(SettingsStore.self) private var settings

    @Binding var selectedReport: Report?

    var body: some View {
        Group {
            if reports.filteredReports.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(reports.filteredReports) { report in
                            Button {
                                selectedReport = report
                            } label: {
                                ReportRow(report: report, highlightCallsign: settings.callsign)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        summaryHeader
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await reports.refresh() }
    }

    private var summaryHeader: some View {
        HStack {
            Text("^[\(reports.filteredReports.count) report](inflect: true)")
            if reports.heardMeCount > 0 {
                Text("· \(reports.heardMeCount) heard you")
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Text(reports.filter.timeWindow.label)
        }
        .font(.caption)
        .textCase(nil)
    }

    private var emptyState: some View {
        Group {
            if reports.isLoading {
                ProgressView("Loading reports…")
            } else {
                ContentUnavailableView {
                    Label("No Reports", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text(descriptionText)
                } actions: {
                    Button("Refresh") { Task { await reports.refresh() } }
                }
            }
        }
    }

    private var descriptionText: String {
        if settings.callsign.isEmpty {
            return "Set your callsign in Settings to see who's hearing your station, or widen the filter."
        }
        return "No spots match the current filter. Try a longer time window or a wider radius."
    }
}
