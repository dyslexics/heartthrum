import Foundation
import SwiftData

@Model
final class PulseRecord {
    var date: Date
    var bpm: Int
    /// Context tag raw value, see MeasureTag
    var tag: String?
    /// Mood 1 (low) ... 3 (good)
    var mood: Int?

    init(date: Date = .now, bpm: Int, tag: String? = nil, mood: Int? = nil) {
        self.date = date
        self.bpm = bpm
        self.tag = tag
        self.mood = mood
    }
}

enum MeasureTag: String, CaseIterable, Identifiable {
    case resting
    case afterActivity
    case morning
    case evening

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .resting: return "Resting"
        case .afterActivity: return "After activity"
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }

    var symbol: String {
        switch self {
        case .resting: return "moon.zzz"
        case .afterActivity: return "figure.run"
        case .morning: return "sunrise"
        case .evening: return "sunset"
        }
    }
}
