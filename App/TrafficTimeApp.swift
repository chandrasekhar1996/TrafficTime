import SwiftUI

@main
struct TrafficTimeApp: App {
    @StateObject private var locationManager = TrafficLocationManager()
    @StateObject private var detector = TrafficDetectionEngine()
    @StateObject private var repository = TrafficRepository()
    @StateObject private var settings = TrafficSettingsStore()
    @StateObject private var coordinator = TrafficMonitoringCoordinator()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(locationManager)
                .environmentObject(detector)
                .environmentObject(repository)
                .environmentObject(settings)
                .onAppear {
                    coordinator.bind(
                        locationManager: locationManager,
                        detector: detector,
                        repository: repository,
                        settings: settings
                    )
                }
        }
    }
}
