import Foundation

/// Where a spot (reception report) came from.
///
/// WSPR spots reach this app one of two ways:
/// - `.radio`  — decoded locally from your radio's audio via the device sound card / microphone.
/// - `.internet` — pulled from the global WSPRnet database (via the wspr.live API).
enum SpotSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case radio
    case internet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .radio: return "Radio"
        case .internet: return "Internet"
        }
    }

    var systemImage: String {
        switch self {
        case .radio: return "antenna.radiowaves.left.and.right"
        case .internet: return "network"
        }
    }
}

/// A filter over spot sources: radio only, internet only, or both.
enum SourceFilter: String, Codable, CaseIterable, Identifiable, Hashable {
    case both
    case radio
    case internet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both: return "Both"
        case .radio: return "Radio"
        case .internet: return "Internet"
        }
    }

    func includes(_ source: SpotSource) -> Bool {
        switch self {
        case .both: return true
        case .radio: return source == .radio
        case .internet: return source == .internet
        }
    }
}
