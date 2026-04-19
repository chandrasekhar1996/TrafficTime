import SwiftUI

struct LiveSessionView: View {
    @EnvironmentObject private var locationManager: TrafficLocationManager
    @EnvironmentObject private var detector: TrafficDetectionEngine

    var body: some View {
        List {
            Section("Location") {
                Text("Lat: \(locationManager.latestCoordinate?.latitude ?? 0, specifier: "%.5f")")
                Text("Lon: \(locationManager.latestCoordinate?.longitude ?? 0, specifier: "%.5f")")
                Text("Road type: \(locationManager.roadType.rawValue)")
            }

            Section("Traffic Detection") {
                Text("State: \(detector.currentState.rawValue)")
                Text("Confidence: \(detector.confidence, specifier: "%.2f")")
            }
        }
        .navigationTitle("Live Session")
    }
}
