import CoreLocation
import XCTest
@testable import TrafficTime

final class TrafficDetectionEngineTests: XCTestCase {
    func testFreewayLowSpeedStillStartsAndEndsEvent() {
        let engine = TrafficDetectionEngine()
        var config = TrafficDetectionConfiguration()
        config.speedThreshold = 50
        config.speedUnit = .mph
        config.startDurationSeconds = 20
        config.endDurationSeconds = 10
        config.minRoadClassConfidence = 0.5

        let base = Date().addingTimeInterval(-120)
        var outputs: [TrafficDetectorOutputEvent] = []

        for second in stride(from: 0, through: 30, by: 5) {
            let mph = second < 15 ? 42.0 : 25.0
            outputs += engine.process(
                sample: makeSample(
                    at: base.addingTimeInterval(TimeInterval(second)),
                    mph: mph,
                    roadType: .freeway,
                    confidence: 0.9
                ),
                configuration: config
            )
        }

        XCTAssertTrue(outputs.contains { if case .started = $0 { return true }; return false })

        outputs.removeAll()
        for second in stride(from: 35, through: 55, by: 5) {
            outputs += engine.process(
                sample: makeSample(
                    at: base.addingTimeInterval(TimeInterval(second)),
                    mph: 62,
                    roadType: .freeway,
                    confidence: 0.9
                ),
                configuration: config
            )
        }

        XCTAssertTrue(outputs.contains { if case .ended = $0 { return true }; return false })
    }

    private func makeSample(
        at date: Date,
        mph: Double,
        roadType: RoadType,
        confidence: Double
    ) -> TrafficSample {
        TrafficSample(
            timestamp: date,
            coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            speedMetersPerSecond: mph * 0.44704,
            horizontalAccuracyMeters: 5,
            roadType: roadType,
            roadClassConfidence: confidence,
            isAutomotiveMotion: true
        )
    }
}
