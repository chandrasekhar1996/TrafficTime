import Foundation

final class TrafficSettingsStore: ObservableObject {
    @Published var speedThresholdMph: Double = 50
    @Published var startDurationSeconds: Double = 25
    @Published var endDurationSeconds: Double = 12
    @Published var minGpsAccuracyMeters: Double = 30
    @Published var useGpsAccuracyFilter: Bool = true
    @Published var autoStartLiveSession: Bool = true

    var detectionConfiguration: TrafficDetectionConfiguration {
        TrafficDetectionConfiguration(
            speedThresholdMph: speedThresholdMph,
            startDurationSeconds: startDurationSeconds,
            endDurationSeconds: endDurationSeconds,
            minGpsAccuracyMeters: useGpsAccuracyFilter ? minGpsAccuracyMeters : nil
        )
    }
}
