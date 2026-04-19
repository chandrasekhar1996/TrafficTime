import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: TrafficSettingsStore

    var body: some View {
        Form {
            Section("Traffic Event Detection") {
                Picker("Speed units", selection: $settings.speedUnit) {
                    ForEach(SpeedUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }

                Stepper(value: $settings.speedThreshold, in: 10...140, step: 1) {
                    Text("Traffic speed threshold: \(settings.speedThreshold, specifier: "%.0f") \(settings.speedUnit.displayName)")
                }

                Stepper(value: $settings.startDurationSeconds, in: 5...180, step: 1) {
                    Text("Continuous low-speed start duration: \(settings.startDurationSeconds, specifier: "%.0f") s")
                }

                Stepper(value: $settings.endDurationSeconds, in: 5...120, step: 1) {
                    Text("End / hysteresis duration: \(settings.endDurationSeconds, specifier: "%.0f") s")
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

            Section("Notifications") {
                Toggle("Notify on traffic event enter/exit", isOn: $settings.notificationsEnabled)
            }

            Section("Behavior") {
                Toggle("Auto-start live session", isOn: $settings.autoStartLiveSession)
            }
        }
        .navigationTitle("Settings")
    }
}
