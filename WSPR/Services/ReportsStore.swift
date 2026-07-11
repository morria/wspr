import Foundation
import CoreLocation
import Observation

/// The single source of truth for reports shown on the map and list. Merges internet
/// spots (wspr.live) with locally decoded radio spots and applies the active filter.
@MainActor
@Observable
final class ReportsStore {

    var filter = ReportFilter()

    /// "My station" context, kept in sync by the UI from Settings / Location.
    var myCallsign = ""
    var myCoordinate: CLLocationCoordinate2D?

    private(set) var internetReports: [Report] = []
    private(set) var radioReports: [Report] = []

    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    private let client = WSPRLiveClient()

    /// Merged, de-duplicated, filtered and sorted (newest first) reports.
    var filteredReports: [Report] {
        let now = Date()
        var seen = Set<String>()
        var merged: [Report] = []
        for report in radioReports + internetReports where !seen.contains(report.id) {
            seen.insert(report.id)
            merged.append(report)
        }
        return merged
            .filter { filter.matches($0, now: now, myCallsign: myCallsign, myCoordinate: myCoordinate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Count of reports of the user's own station being heard (used for a summary badge).
    var heardMeCount: Int {
        let mine = myCallsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !mine.isEmpty else { return 0 }
        return filteredReports.filter { $0.txCallsign.uppercased() == mine }.count
    }

    func attach(receiver: ReceiveController) {
        receiver.onNewReports = { [weak self] reports in
            guard let self else { return }
            self.radioReports.append(contentsOf: reports)
            // Keep memory bounded to the most recent decodes.
            if self.radioReports.count > 2000 {
                self.radioReports.removeFirst(self.radioReports.count - 2000)
            }
        }
    }

    func refresh() async {
        guard filter.source != .radio else {
            // Radio-only: nothing to fetch from the network.
            lastError = nil
            lastUpdated = Date()
            return
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let reports = try await client.fetchReports(filter: filter,
                                                        myCallsign: myCallsign,
                                                        myCoordinate: myCoordinate)
            internetReports = reports
            lastUpdated = Date()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
