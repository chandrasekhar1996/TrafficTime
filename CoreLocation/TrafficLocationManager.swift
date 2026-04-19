import CoreLocation
import CoreMotion
import Foundation

enum RoadType: String {
    case highway = "Highway"
    case arterial = "Arterial"
    case local = "Local"
    case unknown = "Unknown"
}

final class TrafficLocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()

    @Published private(set) var latestCoordinate: CLLocationCoordinate2D?
    @Published private(set) var currentSpeed: CLLocationSpeed = 0
    @Published private(set) var roadType: RoadType = .unknown

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        requestPermissions()
    }

    private func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func updateRoadType(speed: CLLocationSpeed) {
        switch speed {
        case 25...:
            roadType = .highway
        case 12..<25:
            roadType = .arterial
        case 1..<12:
            roadType = .local
        default:
            roadType = .unknown
        }
    }
}

extension TrafficLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latestCoordinate = location.coordinate
        currentSpeed = max(location.speed, 0)
        updateRoadType(speed: currentSpeed)
    }
}
