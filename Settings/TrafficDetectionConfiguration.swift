import Foundation

struct TrafficDetectionConfiguration: Codable, Equatable {
    var speedThresholdMph: Double = 50
    var startDurationSeconds: TimeInterval = 25
    var endDurationSeconds: TimeInterval = 12
    var minGpsAccuracyMeters: Double?

    var speedThresholdMetersPerSecond: Double {
        speedThresholdMph * 0.44704
    }
}
