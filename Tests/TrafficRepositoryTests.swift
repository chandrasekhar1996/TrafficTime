import Foundation
import XCTest
@testable import TrafficTime

final class TrafficRepositoryTests: XCTestCase {
    func testSaveFallsBackToInMemoryStateWhenInsertFails() {
        let store = MockTrafficStore()
        store.insertError = MockError.insertFailed
        let repository = TrafficRepository(store: store)

        let event = makeEvent()
        repository.save(event: event)

        XCTAssertEqual(repository.events.count, 1)
        XCTAssertEqual(repository.events.first?.id, event.id)
        XCTAssertEqual(repository.lastPersistenceError, "Could not persist traffic event.")
    }

    func testRepositoryStartsEmptyWhenLoadFailsAndStillAllowsWrites() {
        let store = MockTrafficStore()
        store.loadError = MockError.openFailed
        let repository = TrafficRepository(store: store)

        XCTAssertEqual(repository.events.count, 0)
        XCTAssertEqual(repository.lastPersistenceError, "Failed to load persisted traffic events.")

        repository.save(event: makeEvent())
        XCTAssertEqual(repository.events.count, 1)
    }

    private func makeEvent() -> TrafficEvent {
        TrafficEvent(
            id: UUID(),
            startTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            endTimestamp: Date(timeIntervalSince1970: 1_700_000_120),
            geometry: [TrafficEventPoint(latitude: 1, longitude: 2)],
            summary: TrafficEventSummary(
                averageSpeedMph: 12,
                minimumSpeedMph: 3,
                maximumSpeedMph: 20,
                sampleCount: 5,
                durationSeconds: 120
            )
        )
    }
}

private final class MockTrafficStore: TrafficStore {
    var loadedEvents: [TrafficEvent] = []
    var loadError: Error?
    var insertError: Error?

    func insert(event: TrafficEvent) throws {
        if let insertError { throw insertError }
        loadedEvents.append(event)
    }

    func loadAllEvents() throws -> [TrafficEvent] {
        if let loadError { throw loadError }
        return loadedEvents
    }

    func clearAll() throws {
        loadedEvents = []
    }
}

private enum MockError: Error {
    case openFailed
    case insertFailed
}
