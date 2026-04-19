import Foundation

struct TrafficEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let state: TrafficState
    let averageSpeed: Double
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
