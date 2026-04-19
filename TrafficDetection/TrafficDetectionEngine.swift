import CoreLocation
import Foundation

enum TrafficState: String {
    case freeFlow = "Free Flow"
    case slowing = "Slowing"
    case congested = "Congested"
    case stopped = "Stopped"
}

struct TrafficSample {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let speedMetersPerSecond: Double
    let horizontalAccuracyMeters: Double
    let roadType: RoadType
    let roadClassConfidence: Double
    let isAutomotiveMotion: Bool
}

struct TrafficEventSummary: Codable {
    let averageSpeedMph: Double
    let minimumSpeedMph: Double
    let maximumSpeedMph: Double
    let sampleCount: Int
    let durationSeconds: TimeInterval
}

struct TrafficSessionCandidate {
    let startTimestamp: Date
}

enum TrafficDetectorOutputEvent {
    case started(TrafficSessionCandidate)
    case ended(TrafficEvent)
}

final class TrafficDetectionEngine: ObservableObject {
    @Published private(set) var currentState: TrafficState = .freeFlow
    @Published private(set) var confidence: Double = 0

    private var speedFilter = RollingSpeedFilter(windowSize: 5, emaAlpha: 0.35)
    private let staleSampleWindowSeconds: TimeInterval = 10

    private var lastTimestamp: Date?
    private var belowThresholdStart: Date?
    private var aboveThresholdStart: Date?
    private var activeEventStart: Date?
    private var activeCoordinates: [CLLocationCoordinate2D] = []
    private var activeSmoothedSpeedsMps: [Double] = []

    func process(sample: TrafficSample, configuration: TrafficDetectionConfiguration) -> [TrafficDetectorOutputEvent] {
        guard shouldProcess(sample: sample, configuration: configuration) else {
            currentState = .freeFlow
            confidence = 0.2
            return []
        }

        let smoothedSpeed = speedFilter.add(speedMetersPerSecond: sample.speedMetersPerSecond)
        updateState(for: smoothedSpeed)

        let threshold = configuration.speedThresholdMetersPerSecond
        var emitted: [TrafficDetectorOutputEvent] = []

        if smoothedSpeed < threshold {
            aboveThresholdStart = nil
            if belowThresholdStart == nil {
                belowThresholdStart = sample.timestamp
            }

            if activeEventStart == nil,
               let belowStart = belowThresholdStart,
               sample.timestamp.timeIntervalSince(belowStart) >= configuration.startDurationSeconds {
                activeEventStart = belowStart
                activeCoordinates = [sample.coordinate]
                activeSmoothedSpeedsMps = [smoothedSpeed]
                emitted.append(.started(TrafficSessionCandidate(startTimestamp: belowStart)))
            } else if activeEventStart != nil {
                activeCoordinates.append(sample.coordinate)
                activeSmoothedSpeedsMps.append(smoothedSpeed)
            }
        } else {
            belowThresholdStart = nil
            if activeEventStart != nil {
                activeCoordinates.append(sample.coordinate)
                activeSmoothedSpeedsMps.append(smoothedSpeed)
            }

            if aboveThresholdStart == nil {
                aboveThresholdStart = sample.timestamp
            }

            if let start = activeEventStart,
               let aboveStart = aboveThresholdStart,
               sample.timestamp.timeIntervalSince(aboveStart) >= configuration.endDurationSeconds {
                emitted.append(.ended(buildEvent(startTimestamp: start, endTimestamp: sample.timestamp)))
                resetActiveEventTracking()
            }
        }

        lastTimestamp = sample.timestamp
        return emitted
    }

    private func shouldProcess(sample: TrafficSample, configuration: TrafficDetectionConfiguration) -> Bool {
        let hasMajorRoadClass = sample.roadType == .highway || sample.roadType == .freeway
        guard hasMajorRoadClass, sample.roadClassConfidence >= configuration.minRoadClassConfidence else {
            return false
        }

        guard sample.isAutomotiveMotion else {
            return false
        }

        if let maxAccuracy = configuration.minGpsAccuracyMeters,
           sample.horizontalAccuracyMeters > maxAccuracy {
            return false
        }

        guard sample.horizontalAccuracyMeters >= 0 else {
            return false
        }

        if let lastTimestamp,
           sample.timestamp <= lastTimestamp {
            return false
        }

        if Date().timeIntervalSince(sample.timestamp) > staleSampleWindowSeconds {
            return false
        }

        return true
    }

    private func updateState(for speedMetersPerSecond: Double) {
        let speedMph = speedMetersPerSecond * 2.23694
        switch speedMph {
        case ..<1:
            currentState = .stopped
            confidence = 0.95
        case ..<20:
            currentState = .congested
            confidence = 0.85
        case ..<50:
            currentState = .slowing
            confidence = 0.7
        default:
            currentState = .freeFlow
            confidence = 0.9
        }
    }

    private func buildEvent(startTimestamp: Date, endTimestamp: Date) -> TrafficEvent {
        let mphSpeeds = activeSmoothedSpeedsMps.map { $0 * 2.23694 }
        let average = mphSpeeds.reduce(0, +) / Double(max(mphSpeeds.count, 1))
        let minSpeed = mphSpeeds.min() ?? 0
        let maxSpeed = mphSpeeds.max() ?? 0

        return TrafficEvent(
            id: UUID(),
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            geometry: activeCoordinates.map(TrafficEventPoint.init),
            summary: TrafficEventSummary(
                averageSpeedMph: average,
                minimumSpeedMph: minSpeed,
                maximumSpeedMph: maxSpeed,
                sampleCount: activeSmoothedSpeedsMps.count,
                durationSeconds: endTimestamp.timeIntervalSince(startTimestamp)
            )
        )
    }

    private func resetActiveEventTracking() {
        activeEventStart = nil
        belowThresholdStart = nil
        aboveThresholdStart = nil
        activeCoordinates = []
        activeSmoothedSpeedsMps = []
    }
}

private struct RollingSpeedFilter {
    private let windowSize: Int
    private let emaAlpha: Double
    private var window: [Double] = []
    private var emaValue: Double?

    init(windowSize: Int, emaAlpha: Double) {
        self.windowSize = max(windowSize, 1)
        self.emaAlpha = min(max(emaAlpha, 0.01), 1)
    }

    mutating func add(speedMetersPerSecond: Double) -> Double {
        window.append(max(speedMetersPerSecond, 0))
        if window.count > windowSize {
            window.removeFirst()
        }

        let sorted = window.sorted()
        let median = sorted[sorted.count / 2]

        if let emaValue {
            let next = emaAlpha * median + (1 - emaAlpha) * emaValue
            self.emaValue = next
            return next
        }

        emaValue = median
        return median
    }
}
