import CoreLocation
import CoreMotion
import Foundation

struct RoadClassEstimate {
    let type: RoadType
    let confidence: Double
    let timestamp: Date
    let source: RoadClassSource

    static func unknown(at timestamp: Date = Date(), source: RoadClassSource = .fallback) -> RoadClassEstimate {
        RoadClassEstimate(type: .unknown, confidence: 0, timestamp: timestamp, source: source)
    }
}

enum RoadClassSource: String {
    case reverseGeocode
    case graceWindow
    case fallback
}

enum RoadType: String {
    case freeway = "Freeway"
    case highway = "Highway"
    case arterial = "Arterial"
    case local = "Local"
    case unknown = "Unknown"

    var isMajorRoadway: Bool {
        self == .freeway || self == .highway
    }
}

protocol RoadClassInferring {
    func inferRoadClass(for location: CLLocation, completion: @escaping (RoadClassEstimate?) -> Void)
}

final class ReverseGeocodeRoadClassInferer: RoadClassInferring {
    private let geocoder = CLGeocoder()

    func inferRoadClass(for location: CLLocation, completion: @escaping (RoadClassEstimate?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }

            let candidateName = [placemark.thoroughfare, placemark.subThoroughfare, placemark.name]
                .compactMap { $0 }
                .joined(separator: " ")

            guard !candidateName.isEmpty else {
                completion(nil)
                return
            }

            let estimate = self.classifyRoad(named: candidateName, timestamp: location.timestamp)
            completion(estimate)
        }
    }

    private func classifyRoad(named name: String, timestamp: Date) -> RoadClassEstimate {
        let normalized = name.lowercased()

        if normalized.contains("interstate") || normalized.contains(" freeway") || normalized.contains(" fwy") || normalized.contains(" i-") {
            return RoadClassEstimate(type: .freeway, confidence: 0.95, timestamp: timestamp, source: .reverseGeocode)
        }

        if normalized.contains("highway") || normalized.contains(" hwy") || normalized.contains(" us-") || normalized.contains("state route") || normalized.contains("route") || normalized.contains("turnpike") {
            return RoadClassEstimate(type: .highway, confidence: 0.82, timestamp: timestamp, source: .reverseGeocode)
        }

        if normalized.contains("boulevard") || normalized.contains(" blvd") || normalized.contains(" avenue") || normalized.contains(" ave") || normalized.contains("road") || normalized.contains(" rd") || normalized.contains("parkway") || normalized.contains(" pkwy") {
            return RoadClassEstimate(type: .arterial, confidence: 0.7, timestamp: timestamp, source: .reverseGeocode)
        }

        if normalized.contains("street") || normalized.contains(" st") || normalized.contains("drive") || normalized.contains(" dr") || normalized.contains("lane") || normalized.contains(" ln") {
            return RoadClassEstimate(type: .local, confidence: 0.62, timestamp: timestamp, source: .reverseGeocode)
        }

        return RoadClassEstimate(type: .unknown, confidence: 0.25, timestamp: timestamp, source: .reverseGeocode)
    }
}

final class TrafficLocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()
    private let roadClassInferer: RoadClassInferring
    private let majorRoadGraceWindowSeconds: TimeInterval

    private var lastMajorRoadEstimate: RoadClassEstimate?

    @Published private(set) var latestCoordinate: CLLocationCoordinate2D?
    @Published private(set) var currentSpeed: CLLocationSpeed = 0
    @Published private(set) var roadType: RoadType = .unknown
    @Published private(set) var roadClass: RoadClassEstimate = .unknown()
    @Published private(set) var isAutomotiveMotion: Bool = false
    @Published private(set) var latestSample: TrafficSample?

    init(
        roadClassInferer: RoadClassInferring = ReverseGeocodeRoadClassInferer(),
        majorRoadGraceWindowSeconds: TimeInterval = 90
    ) {
        self.roadClassInferer = roadClassInferer
        self.majorRoadGraceWindowSeconds = majorRoadGraceWindowSeconds
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

    private func updateRoadClass(for location: CLLocation) {
        roadClassInferer.inferRoadClass(for: location) { [weak self] inferredClass in
            guard let self else { return }

            let effectiveClass = self.resolveEffectiveRoadClass(inferredClass: inferredClass, at: location.timestamp)
            DispatchQueue.main.async {
                self.roadClass = effectiveClass
                self.roadType = effectiveClass.type
                self.publishLatestSample(for: location)
            }
        }
    }

    private func resolveEffectiveRoadClass(inferredClass: RoadClassEstimate?, at timestamp: Date) -> RoadClassEstimate {
        if let inferredClass {
            if inferredClass.type.isMajorRoadway && inferredClass.confidence >= 0.6 {
                lastMajorRoadEstimate = inferredClass
                return inferredClass
            }

            if let heldMajorRoadClass = retainedMajorRoadClass(at: timestamp),
               inferredClass.confidence < 0.7 {
                return heldMajorRoadClass
            }

            return inferredClass
        }

        if let heldMajorRoadClass = retainedMajorRoadClass(at: timestamp) {
            return heldMajorRoadClass
        }

        return RoadClassEstimate.unknown(at: timestamp)
    }

    private func retainedMajorRoadClass(at timestamp: Date) -> RoadClassEstimate? {
        guard let lastMajorRoadEstimate else { return nil }

        let age = timestamp.timeIntervalSince(lastMajorRoadEstimate.timestamp)
        guard age >= 0, age <= majorRoadGraceWindowSeconds else { return nil }

        return RoadClassEstimate(
            type: lastMajorRoadEstimate.type,
            confidence: max(lastMajorRoadEstimate.confidence - (age / majorRoadGraceWindowSeconds) * 0.35, 0.5),
            timestamp: timestamp,
            source: .graceWindow
        )
    }

    private func publishLatestSample(for location: CLLocation) {
        latestSample = TrafficSample(
            timestamp: location.timestamp,
            coordinate: location.coordinate,
            speedMetersPerSecond: currentSpeed,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            roadType: roadClass.type,
            roadClassConfidence: roadClass.confidence,
            isAutomotiveMotion: isAutomotiveMotion
        )
    }
}

extension TrafficLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latestCoordinate = location.coordinate
        currentSpeed = max(location.speed, 0)

        publishLatestSample(for: location)
        updateRoadClass(for: location)
    }
}
