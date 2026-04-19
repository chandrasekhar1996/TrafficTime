import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var store: SessionStore
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                detectionSection
                unitsSection
                trackingSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { store.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Permanently delete \(store.sessions.count) recorded sessions.")
            }
        }
    }

    // MARK: - Sections

    private var detectionSection: some View {
        Section {
            sliderRow(
                label: "Speed Threshold",
                value: $settings.speedThresholdMph,
                range: 20...80, step: 5,
                display: "\(Int(settings.speedThresholdDisplay)) \(settings.speedUnit)"
            )

            sliderRow(
                label: "Entry Confirmation",
                value: $settings.entryConfirmationSeconds,
                range: 5...120, step: 5,
                display: "\(Int(settings.entryConfirmationSeconds))s",
                minLabel: "5s", maxLabel: "120s"
            )

            sliderRow(
                label: "Exit Confirmation",
                value: $settings.exitConfirmationSeconds,
                range: 10...120, step: 5,
                display: "\(Int(settings.exitConfirmationSeconds))s",
                minLabel: "10s", maxLabel: "120s"
            )
        } header: {
            Text("Detection")
        } footer: {
            Text("Traffic is confirmed after speed stays below the threshold for the entry confirmation duration.")
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            Toggle("Use km/h", isOn: $settings.useKmh)
        }
    }

    private var trackingSection: some View {
        Section("Tracking") {
            Toggle("Active Tracking", isOn: $settings.isTracking)
                .onChange(of: settings.isTracking) { _, active in
                    active ? locationManager.startTracking() : locationManager.stopTracking()
                }

            HStack {
                Text("Location Permission")
                Spacer()
                Text(locationManager.authorizationStatus.label)
                    .font(.caption)
                    .foregroundColor(locationManager.authorizationStatus == .authorizedAlways ? .green : .orange)
            }

            if locationManager.authorizationStatus != .authorizedAlways {
                Button("Open Settings for Always Permission") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Sessions Recorded", value: "\(store.sessions.count)")
            LabeledContent("Total Time", value: formatDuration(store.totalDuration))
            Button("Delete All Data", role: .destructive) { showDeleteAlert = true }
        }
    }

    private var aboutSection: some View {
        Section("How It Works") {
            Text("TrafficTime monitors your GPS speed in the background. When speed drops below **\(Int(settings.speedThresholdDisplay)) \(settings.speedUnit)** for **\(Int(settings.entryConfirmationSeconds)) seconds**, a traffic event begins. The event ends when speed sustains above the threshold for **\(Int(settings.exitConfirmationSeconds)) seconds**.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String,
        minLabel: String = "20",
        maxLabel: String = "80"
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(display).foregroundColor(.secondary)
            }
            Slider(value: value, in: range, step: step) {
                Text(label)
            } minimumValueLabel: {
                Text(minLabel).font(.caption2)
            } maximumValueLabel: {
                Text(maxLabel).font(.caption2)
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
