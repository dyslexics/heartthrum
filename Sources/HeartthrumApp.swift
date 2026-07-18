import SwiftUI
import SwiftData

@main
struct HeartthrumApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: PulseRecord.self)
    }
}
