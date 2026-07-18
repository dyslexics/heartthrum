import Foundation
import SwiftData

/// Screenshot/demo support: launch with "-demoData" to fill the history
/// with sample measurements. Never active in normal use.
enum DemoData {
    static func seedIfRequested(container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains("-demoData") else { return }
        let ctx = ModelContext(container)
        try? ctx.delete(model: PulseRecord.self)
        let now = Date()
        let entries: [(daysAgo: Double, bpm: Int, tag: String?, mood: Int?)] = [
            (0.05, 66, "resting", 3),
            (0.4, 81, "afterActivity", 3),
            (0.9, 63, "morning", 2),
            (1.3, 71, nil, nil),
            (2.1, 68, "evening", 3),
            (3.0, 75, "afterActivity", 2),
            (4.2, 62, "morning", 3),
            (5.5, 70, "resting", 2),
            (7.0, 65, "resting", 3),
            (9.4, 84, "afterActivity", 3),
            (12.0, 67, "evening", 2),
            (15.2, 64, "morning", 3),
            (19.8, 72, nil, 2),
            (24.5, 61, "resting", 3),
            (28.9, 69, "morning", 3),
        ]
        for e in entries {
            ctx.insert(PulseRecord(date: now.addingTimeInterval(-e.daysAgo * 86_400),
                                   bpm: e.bpm, tag: e.tag, mood: e.mood))
        }
        try? ctx.save()
    }
}
