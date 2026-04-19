import SwiftUI

@main
struct TrafficTimeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.settings)
                .environmentObject(appState.locationManager)
                .environmentObject(appState.sessionStore)
                .environmentObject(appState.trafficDetector)
        }
    }
}
