import CoreLocation
import CoreMotion
import Foundation

enum RoadType: String {
    case freeway = "Freeway"
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
    @Published private(set) var isAutomotiveMotion: Bool = false
    @Published private(set) var latestSample: TrafficSample?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        requestPermissions()
        startMotionUpdatesIfAvailable()
    }

    private func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func startMotionUpdatesIfAvailable() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.isAutomotiveMotion = activity.automotive && !activity.stationary
        }
    }

    private func updateRoadType(speed: CLLocationSpeed) {
        switch speed {
        case 33...:
            roadType = .freeway
        case 25..<33:
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

        latestSample = TrafficSample(
            timestamp: location.timestamp,
            coordinate: location.coordinate,
            speedMetersPerSecond: currentSpeed,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            roadType: roadType,
            isAutomotiveMotion: isAutomotiveMotion
        )
    }
}
