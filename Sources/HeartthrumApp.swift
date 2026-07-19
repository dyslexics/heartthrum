import SwiftUI
import SwiftData

@main
struct HeartthrumApp: App {
    let container: ModelContainer

    init() {
        container = try! ModelContainer(for: PulseRecord.self)
        DemoData.seedIfRequested(container: container)
        CameraInfo.detect()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
