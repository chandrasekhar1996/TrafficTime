import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: TrafficSettingsStore

    var body: some View {
        Form {
            Section("Traffic Event Detection") {
                Stepper(value: $settings.speedThresholdMph, in: 10...85, step: 1) {
                    Text("Speed threshold: \(settings.speedThresholdMph, specifier: "%.0f") mph")
                }
                Stepper(value: $settings.startDurationSeconds, in: 5...120, step: 1) {
                    Text("Start duration: \(settings.startDurationSeconds, specifier: "%.0f") s")
                }
                Stepper(value: $settings.endDurationSeconds, in: 5...60, step: 1) {
                    Text("End duration: \(settings.endDurationSeconds, specifier: "%.0f") s")
                }
            }

            Section("GPS Quality") {
                Toggle("Filter low-accuracy GPS points", isOn: $settings.useGpsAccuracyFilter)
                if settings.useGpsAccuracyFilter {
                    Stepper(value: $settings.minGpsAccuracyMeters, in: 5...100, step: 1) {
                        Text("Max horizontal accuracy: \(settings.minGpsAccuracyMeters, specifier: "%.0f") m")
                    }
                }
            }

            Section("Behavior") {
                Toggle("Auto-start live session", isOn: $settings.autoStartLiveSession)
            }
        }
        .navigationTitle("Settings")
    }
}
