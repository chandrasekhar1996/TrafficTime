import CoreLocation
import Foundation

struct TrafficEventPoint: Codable {
    let latitude: Double
    let longitude: Double


    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

struct TrafficEvent: Identifiable, Codable {
    let id: UUID
    let startTimestamp: Date
    let endTimestamp: Date
    let geometry: [TrafficEventPoint]
    let summary: TrafficEventSummary
}

final class TrafficRepository: ObservableObject {
    @Published private(set) var events: [TrafficEvent] = []

    func save(event: TrafficEvent) {
        events.append(event)
    }

    func clear() {
        events.removeAll()
    }
}
