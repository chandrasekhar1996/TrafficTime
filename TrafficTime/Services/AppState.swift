import Foundation

class AppState: ObservableObject {
    let settings = AppSettings()
    let locationManager = LocationManager()
    let sessionStore = SessionStore()
    lazy var trafficDetector = TrafficDetector(settings: settings)

    init() {
        wire()
        if settings.isTracking {
            locationManager.requestPermission()
            locationManager.startTracking()
        }
    }

    private func wire() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.trafficDetector.process(location: location)
        }
        trafficDetector.onSessionEnded = { [weak self] session in
            DispatchQueue.main.async { self?.sessionStore.save(session) }
        }
    }
}
