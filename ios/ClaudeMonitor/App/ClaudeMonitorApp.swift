import SwiftUI
import SwiftData

@main
struct ClaudeMonitorApp: App {
    @State private var sessionsManager = SessionsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionsManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [CachedSession.self, CachedEvent.self])
    }
}
