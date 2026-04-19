import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: TrafficSettingsStore

    var body: some View {
        Form {
            Section("Detection Thresholds") {
                Stepper(value: $settings.slowThreshold, in: 1...20, step: 0.5) {
                    Text("Slow: \(settings.slowThreshold, specifier: "%.1f") m/s")
                }
                Stepper(value: $settings.congestedThreshold, in: 0.5...10, step: 0.5) {
                    Text("Congested: \(settings.congestedThreshold, specifier: "%.1f") m/s")
                }
                Stepper(value: $settings.stoppedThreshold, in: 0.1...3, step: 0.1) {
                    Text("Stopped: \(settings.stoppedThreshold, specifier: "%.1f") m/s")
                }
            }

            Section("Behavior") {
                Toggle("Auto-start live session", isOn: $settings.autoStartLiveSession)
            }
        }
        .navigationTitle("Settings")
    }
}
