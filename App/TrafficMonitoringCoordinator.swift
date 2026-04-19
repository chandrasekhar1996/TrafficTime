import Combine
import Foundation
import UserNotifications

final class TrafficMonitoringCoordinator: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []
    private let notifier = TrafficEventNotifier()

    func bind(
        locationManager: TrafficLocationManager,
        detector: TrafficDetectionEngine,
        repository: TrafficRepository,
        settings: TrafficSettingsStore
    ) {
        guard cancellables.isEmpty else { return }

        locationManager.$latestSample
            .compactMap { $0 }
            .sink { [weak self] sample in
                let outputs = detector.process(sample: sample, configuration: settings.detectionConfiguration)
                for output in outputs {
                    switch output {
                    case .started:
                        if settings.notificationsEnabled {
                            self?.notifier.notify(title: "Traffic event started", body: "Low-speed traffic detected.")
                        }
                    case let .ended(event):
                        repository.save(event: event)
                        if settings.notificationsEnabled {
                            self?.notifier.notify(title: "Traffic event ended", body: "Duration: \(Int(event.summary.durationSeconds)) seconds")
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}

private final class TrafficEventNotifier {
    private var didRequestPermission = false

    func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        if !didRequestPermission {
            didRequestPermission = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
