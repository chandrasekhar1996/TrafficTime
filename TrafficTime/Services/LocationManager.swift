import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var currentSpeedMph: Double = -1
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdating: Bool = false

    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0, loc.speed >= 0 else { return }
        let mph = loc.speed * 2.23694
        DispatchQueue.main.async { self.currentSpeedMph = mph }
        onLocationUpdate?(loc)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.authorizationStatus = manager.authorizationStatus }
        if manager.authorizationStatus == .authorizedAlways ||
           manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension CLAuthorizationStatus {
    var label: String {
        switch self {
        case .authorizedAlways:    return "Always ✓"
        case .authorizedWhenInUse: return "When In Use"
        case .denied:              return "Denied ✗"
        case .restricted:          return "Restricted"
        case .notDetermined:       return "Not Asked"
        @unknown default:          return "Unknown"
        }
    }
}
