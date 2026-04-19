import Foundation

enum SpeedUnit: String, Codable, CaseIterable, Identifiable {
    case mph
    case kmh

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }

    var metersPerSecondFactor: Double {
        switch self {
        case .mph:
            return 0.44704
        case .kmh:
            return 0.277778
        }
    }

    func toDisplaySpeed(fromMetersPerSecond speedMps: Double) -> Double {
        speedMps / metersPerSecondFactor
    }

    func toMetersPerSecond(fromDisplaySpeed speed: Double) -> Double {
        speed * metersPerSecondFactor
    }
}

struct TrafficDetectionConfiguration: Codable, Equatable {
    var speedThreshold: Double = 50
    var speedUnit: SpeedUnit = .mph
    var startDurationSeconds: TimeInterval = 25
    var endDurationSeconds: TimeInterval = 12
    var minGpsAccuracyMeters: Double?

    var speedThresholdMetersPerSecond: Double {
        speedUnit.toMetersPerSecond(fromDisplaySpeed: speedThreshold)
    }
}
