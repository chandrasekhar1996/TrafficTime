import Foundation

enum TrafficState: String {
    case freeFlow = "Free Flow"
    case slowing = "Slowing"
    case congested = "Congested"
    case stopped = "Stopped"
}

struct DetectionThresholds {
    var slowSpeed: Double = 8
    var congestionSpeed: Double = 4
    var stoppedSpeed: Double = 0.5
}

final class TrafficDetectionEngine: ObservableObject {
    @Published private(set) var currentState: TrafficState = .freeFlow
    @Published private(set) var confidence: Double = 0

    var thresholds = DetectionThresholds()

    func ingest(speed: Double) {
        if speed <= thresholds.stoppedSpeed {
            currentState = .stopped
            confidence = 0.95
        } else if speed <= thresholds.congestionSpeed {
            currentState = .congested
            confidence = 0.85
        } else if speed <= thresholds.slowSpeed {
            currentState = .slowing
            confidence = 0.7
        } else {
            currentState = .freeFlow
            confidence = 0.9
        }
    }
}
