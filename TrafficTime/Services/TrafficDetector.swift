import Foundation
import CoreLocation

enum DetectionState {
    case idle
    case potentialEntry(since: Date, points: [TrafficPoint])
    case inTraffic(since: Date, points: [TrafficPoint])
    case potentialExit(since: Date, trafficSince: Date, points: [TrafficPoint])
}

class TrafficDetector: ObservableObject {
    @Published var isInTraffic: Bool = false
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var entryCountdown: Double = 0

    var settings: AppSettings
    var onSessionEnded: ((TrafficSession) -> Void)?

    private(set) var state: DetectionState = .idle
    private var ticker: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func process(location: CLLocation) {
        guard location.speed >= 0 else { return }
        let speedMph = location.speed * 2.23694
        let isBelow = speedMph < settings.speedThresholdMph
        let now = location.timestamp
        let point = TrafficPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: now,
            speedMph: speedMph
        )
        DispatchQueue.main.async { self.advance(isBelow: isBelow, point: point, now: now) }
    }

    private func advance(isBelow: Bool, point: TrafficPoint, now: Date) {
        switch state {
        case .idle:
            if isBelow {
                state = .potentialEntry(since: now, points: [point])
                entryCountdown = 0
            }

        case .potentialEntry(let since, var points):
            points.append(point)
            if !isBelow {
                state = .idle
                entryCountdown = 0
            } else {
                let elapsed = now.timeIntervalSince(since)
                entryCountdown = min(elapsed / settings.entryConfirmationSeconds, 1.0)
                if elapsed >= settings.entryConfirmationSeconds {
                    state = .inTraffic(since: since, points: points)
                    isInTraffic = true
                    startTicker(trafficStart: since)
                } else {
                    state = .potentialEntry(since: since, points: points)
                }
            }

        case .inTraffic(let since, var points):
            points.append(point)
            currentSessionDuration = now.timeIntervalSince(since)
            if !isBelow {
                state = .potentialExit(since: now, trafficSince: since, points: points)
            } else {
                state = .inTraffic(since: since, points: points)
            }

        case .potentialExit(let exitSince, let trafficSince, var points):
            points.append(point)
            if isBelow {
                state = .inTraffic(since: trafficSince, points: points)
            } else if now.timeIntervalSince(exitSince) >= settings.exitConfirmationSeconds {
                finalizeSession(trafficSince: trafficSince, endTime: exitSince, points: points)
            }
        }
    }

    private func startTicker(trafficStart: Date) {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            switch self.state {
            case .inTraffic(let since, _):
                self.currentSessionDuration = Date().timeIntervalSince(since)
            case .potentialExit(let exitSince, let trafficSince, let points):
                if Date().timeIntervalSince(exitSince) >= self.settings.exitConfirmationSeconds {
                    self.finalizeSession(trafficSince: trafficSince, endTime: exitSince, points: points)
                }
            default: break
            }
        }
    }

    private func finalizeSession(trafficSince: Date, endTime: Date, points: [TrafficPoint]) {
        ticker?.invalidate()
        ticker = nil
        let duration = endTime.timeIntervalSince(trafficSince)
        guard duration >= 1 else {
            reset()
            return
        }
        let session = TrafficSession(startTime: trafficSince, endTime: endTime, duration: duration, points: points)
        reset()
        onSessionEnded?(session)
    }

    private func reset() {
        state = .idle
        isInTraffic = false
        currentSessionDuration = 0
        entryCountdown = 0
    }
}
