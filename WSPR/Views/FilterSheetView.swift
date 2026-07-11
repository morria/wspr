import SwiftUI

/// Controls which reports appear on the map/list: source, "heard me", time window,
/// band, and a radius around a chosen center.
struct FilterSheetView: View {
    @Environment(ReportsStore.self) private var reports
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var reports = reports
        NavigationStack {
            Form {
                // MARK: Source
                Section {
                    Picker("Source", selection: $reports.filter.source) {
                        ForEach(SourceFilter.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Only stations hearing me", isOn: $reports.filter.onlyStationsHearingMe)
                } header: {
                    Text("Source")
                } footer: {
                    if reports.filter.onlyStationsHearingMe && settings.callsign.isEmpty {
                        Text("Set your callsign in Settings to use this filter.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Radio spots are decoded locally from your receiver; internet spots come from the WSPRnet database via wspr.live.")
                    }
                }

                // MARK: Time
                Section("Time Window") {
                    Picker("Show reports from", selection: timeSelection) {
                        ForEach(TimeWindow.presets, id: \.self) { minutes in
                            Text(TimeWindow.minutes(minutes).label).tag(minutes)
                        }
                        Text("Custom range").tag(-1)
                    }

                    if case .range(let start, let end) = reports.filter.timeWindow {
                        DatePicker("From", selection: rangeStartBinding(start: start, end: end),
                                   in: ...end, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("To", selection: rangeEndBinding(start: start, end: end),
                                   in: start...Date(), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                // MARK: Band
                Section("Band") {
                    Picker("Band", selection: bandSelection) {
                        Text("All bands").tag(-1)
                        ForEach(Band.all) { band in
                            Text(band.name).tag(band.dialFrequency)
                        }
                    }
                }

                // MARK: Radius
                Section {
                    Toggle("Limit by distance", isOn: $reports.filter.radiusEnabled)

                    if reports.filter.radiusEnabled {
                        Picker("Center", selection: centerKind) {
                            Text("My station").tag(0)
                            Text("A grid square").tag(1)
                        }

                        if case .grid = reports.filter.radiusCenter {
                            TextField("Grid square (e.g. FN20)", text: centerGrid)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading) {
                            HStack {
                                Text("Radius")
                                Spacer()
                                Text("\(Int(reports.filter.radiusKm)) km").foregroundStyle(.secondary)
                            }
                            Slider(value: $reports.filter.radiusKm, in: 50...5000, step: 50)
                        }
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    Text("Show only stations within the chosen radius of your station, your grid square, or any other grid square.")
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { reports.filter = ReportFilter() }
                        .disabled(reports.filter.isDefault)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Derived bindings

    private var timeSelection: Binding<Int> {
        Binding(
            get: {
                if case .minutes(let m) = reports.filter.timeWindow { return m }
                return -1
            },
            set: { newValue in
                if newValue == -1 {
                    let end = Date()
                    reports.filter.timeWindow = .range(start: end.addingTimeInterval(-3600), end: end)
                } else {
                    reports.filter.timeWindow = .minutes(newValue)
                }
            }
        )
    }

    private func rangeStartBinding(start: Date, end: Date) -> Binding<Date> {
        Binding(get: { start }, set: { reports.filter.timeWindow = .range(start: $0, end: end) })
    }

    private func rangeEndBinding(start: Date, end: Date) -> Binding<Date> {
        Binding(get: { end }, set: { reports.filter.timeWindow = .range(start: start, end: $0) })
    }

    private var bandSelection: Binding<Int> {
        Binding(
            get: { reports.filter.band?.dialFrequency ?? -1 },
            set: { dial in reports.filter.band = Band.all.first { $0.dialFrequency == dial } }
        )
    }

    private var centerKind: Binding<Int> {
        Binding(
            get: {
                if case .myStation = reports.filter.radiusCenter { return 0 }
                return 1
            },
            set: { kind in
                reports.filter.radiusCenter = kind == 0 ? .myStation : .grid(settings.gridSquare)
            }
        )
    }

    private var centerGrid: Binding<String> {
        Binding(
            get: {
                if case .grid(let g) = reports.filter.radiusCenter { return g }
                return ""
            },
            set: { reports.filter.radiusCenter = .grid($0) }
        )
    }
}
