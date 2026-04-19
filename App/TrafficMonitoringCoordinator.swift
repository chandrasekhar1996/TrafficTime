import Combine
import Foundation

final class TrafficMonitoringCoordinator: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []

    func bind(
        locationManager: TrafficLocationManager,
        detector: TrafficDetectionEngine,
        repository: TrafficRepository,
        settings: TrafficSettingsStore
    ) {
        guard cancellables.isEmpty else { return }

        locationManager.$latestSample
            .compactMap { $0 }
            .sink { sample in
                let outputs = detector.process(sample: sample, configuration: settings.detectionConfiguration)
                for output in outputs {
                    switch output {
                    case .started:
                        break
                    case let .ended(event):
                        repository.save(event: event)
                    }
                }
            }
            .store(in: &cancellables)
    }
}
