import SwiftUI

/// Top-level screen: a map or list of WSPR reports with the transmit console
/// available as a hideable bottom sheet, following the iOS bottom-sheet idiom.
struct RootView: View {
    enum ViewMode: String, CaseIterable, Identifiable {
        case map = "Map"
        case list = "List"
        var id: String { rawValue }
        var systemImage: String { self == .map ? "map" : "list.bullet" }
    }

    @Environment(SettingsStore.self) private var settings
    @Environment(LocationManager.self) private var location
    @Environment(ReportsStore.self) private var reports

    @State private var viewMode: ViewMode = .map
    @State private var showTransmit = false
    @State private var showFilter = false
    @State private var showSettings = false
    @State private var selectedReport: Report?

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showTransmit) {
                    TransmitSheetView()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                }
                .sheet(isPresented: $showFilter) {
                    FilterSheetView()
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .sheet(item: $selectedReport) { report in
                    NavigationStack { ReportDetailView(report: report) }
                        .presentationDetents([.medium, .large])
                }
        }
        .task { await bootstrap() }
        .onChange(of: settings.callsign) { syncContext() }
        .onChange(of: location.coordinate?.latitude) { syncContext() }
        .onChange(of: showFilter) { _, isShowing in
            // Refetch once when the filter sheet closes (avoids hammering wspr.live
            // on every slider tick; time/source changes filter existing data live).
            if !isShowing { Task { await reports.refresh() } }
        }
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        ZStack(alignment: .bottom) {
            switch viewMode {
            case .map:
                ReportsMapView(selectedReport: $selectedReport)
                    .ignoresSafeArea(edges: .top)
            case .list:
                ReportsListView(selectedReport: $selectedReport)
            }

            if let error = reports.lastError {
                ErrorBanner(message: error)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: reports.lastError)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                showFilter = true
            } label: {
                Image(systemName: reports.filter.isDefault
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Filter reports")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }

        ToolbarItem(placement: .bottomBar) {
            TransmitBar(showTransmit: $showTransmit)
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        location.requestPermission()
        syncContext()
        await reports.refresh()
        // Periodic refresh aligned roughly to WSPR's 2-minute cadence.
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 120 * 1_000_000_000)
            await reports.refresh()
        }
    }

    private func syncContext() {
        reports.myCallsign = settings.callsign
        reports.myCoordinate = location.coordinate
            ?? MaidenheadLocator.coordinate(from: settings.gridSquare)
        if settings.followLocation, let grid = location.gridSquare {
            settings.gridSquare = grid
        }
    }
}

/// The bottom-bar entry point to the transmit sheet; shows live TX status when active.
private struct TransmitBar: View {
    @Environment(TransmitController.self) private var transmitter
    @Environment(ReportsStore.self) private var reports
    @Binding var showTransmit: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showTransmit = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: transmitter.isEnabled ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .symbolEffect(.variableColor.iterative, isActive: transmitter.phase == .transmitting)
                    Text(statusText)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(transmitter.isEnabled ? Color.accentColor : .primary)
            }

            Spacer()

            if reports.isLoading {
                ProgressView().controlSize(.small)
            } else if let updated = reports.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        guard transmitter.isEnabled else { return "Transmit" }
        switch transmitter.phase {
        case .idle: return "Transmit"
        case .waiting: return "TX in \(timeString(transmitter.secondsUntilNextTransmission))"
        case .transmitting: return "On air · \(timeString(transmitter.secondsRemaining)) left"
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// A dismissible error banner.
private struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.orange.opacity(0.4)))
        .foregroundStyle(.orange)
    }
}
