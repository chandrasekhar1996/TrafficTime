import Foundation
import XCTest
@testable import TrafficTime

final class TrafficSpatialAggregationTests: XCTestCase {
    func testHotspotAggregationCountsSingleLongEventOnce() {
        let event = makeEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            durationSeconds: 120,
            averageSpeedMph: 10,
            points: Array(repeating: TrafficEventPoint(latitude: 37.7749, longitude: -122.4194), count: 12)
        )

        let hotspots = TrafficSpatialAggregation.hotspotAggregations(from: [event])

        XCTAssertEqual(hotspots.count, 1)
        XCTAssertEqual(hotspots.first?.eventCount, 1)
    }

    func testHotspotAggregationCountsTwoDistinctEvents() {
        let eventA = makeEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            durationSeconds: 30,
            averageSpeedMph: 8,
            points: [
                TrafficEventPoint(latitude: 34.0522, longitude: -118.2437),
                TrafficEventPoint(latitude: 34.0523, longitude: -118.2437)
            ]
        )
        let eventB = makeEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
            durationSeconds: 40,
            averageSpeedMph: 7,
            points: [
                TrafficEventPoint(latitude: 34.0522, longitude: -118.2437),
                TrafficEventPoint(latitude: 34.0523, longitude: -118.2437)
            ]
        )

        let hotspots = TrafficSpatialAggregation.hotspotAggregations(from: [eventA, eventB])

        XCTAssertEqual(hotspots.count, 1)
        XCTAssertEqual(hotspots.first?.eventCount, 2)
    }

    private func makeEvent(
        id: UUID,
        durationSeconds: TimeInterval,
        averageSpeedMph: Double,
        points: [TrafficEventPoint]
    ) -> TrafficEvent {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        return TrafficEvent(
            id: id,
            startTimestamp: start,
            endTimestamp: start.addingTimeInterval(durationSeconds),
            geometry: points,
            summary: TrafficEventSummary(
                averageSpeedMph: averageSpeedMph,
                minimumSpeedMph: averageSpeedMph,
                maximumSpeedMph: averageSpeedMph,
                sampleCount: points.count,
                durationSeconds: durationSeconds
            )
        )
    }
}
