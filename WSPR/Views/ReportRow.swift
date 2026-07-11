import SwiftUI

/// One report as a list row: heard station, reporter, band, signal and age.
struct ReportRow: View {
    let report: Report
    var highlightCallsign: String = ""

    private var isMine: Bool {
        let mine = highlightCallsign.trimmingCharacters(in: .whitespaces).uppercased()
        return !mine.isEmpty && report.txCallsign.uppercased() == mine
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(report.bandColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(report.txCallsign)
                        .font(.body.weight(.semibold))
                    if isMine {
                        Text("YOU")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Image(systemName: report.source.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "ear")
                        .font(.caption2)
                    Text(report.rxCallsign)
                    if !report.rxGrid.isEmpty {
                        Text("· \(report.rxGrid)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(report.bandName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(report.bandColor.opacity(0.18), in: Capsule())
                Text(ReportFormatting.snr(report.snr))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(ReportFormatting.distance(report.distanceKm)) · \(ReportFormatting.age(report.timestamp))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
