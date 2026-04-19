import Foundation
import CoreLocation

struct TrafficSession: Codable, Identifiable {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var points: [TrafficPoint]

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

struct TrafficPoint: Codable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var speedMph: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
