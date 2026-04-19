import SwiftUI

@main
struct TrafficTimeApp: App {
    @StateObject private var locationManager = TrafficLocationManager()
    @StateObject private var detector = TrafficDetectionEngine()
    @StateObject private var repository = TrafficRepository()
    @StateObject private var settings = TrafficSettingsStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(locationManager)
                .environmentObject(detector)
                .environmentObject(repository)
                .environmentObject(settings)
        }
    }
}
