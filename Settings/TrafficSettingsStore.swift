import Combine
import Foundation

final class TrafficSettingsStore: ObservableObject {
    @Published var speedThreshold: Double = 50
    @Published var speedUnit: SpeedUnit = .mph
    @Published var startDurationSeconds: Double = 25
    @Published var endDurationSeconds: Double = 12
    @Published var minGpsAccuracyMeters: Double = 30
    @Published var useGpsAccuracyFilter: Bool = true
    @Published var autoStartLiveSession: Bool = true
    @Published var notificationsEnabled: Bool = false

    private let userDefaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
        bindPersistence()
    }

    var detectionConfiguration: TrafficDetectionConfiguration {
        TrafficDetectionConfiguration(
            speedThreshold: speedThreshold,
            speedUnit: speedUnit,
            startDurationSeconds: startDurationSeconds,
            endDurationSeconds: endDurationSeconds,
            minGpsAccuracyMeters: useGpsAccuracyFilter ? minGpsAccuracyMeters : nil
        )
    }

    private func load() {
        speedThreshold = userDefaults.object(forKey: Keys.speedThreshold) as? Double ?? 50
        speedUnit = SpeedUnit(rawValue: userDefaults.string(forKey: Keys.speedUnit) ?? "mph") ?? .mph
        startDurationSeconds = userDefaults.object(forKey: Keys.startDurationSeconds) as? Double ?? 25
        endDurationSeconds = userDefaults.object(forKey: Keys.endDurationSeconds) as? Double ?? 12
        minGpsAccuracyMeters = userDefaults.object(forKey: Keys.minGpsAccuracyMeters) as? Double ?? 30
        useGpsAccuracyFilter = userDefaults.object(forKey: Keys.useGpsAccuracyFilter) as? Bool ?? true
        autoStartLiveSession = userDefaults.object(forKey: Keys.autoStartLiveSession) as? Bool ?? true
        notificationsEnabled = userDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? false
    }

    private func bindPersistence() {
        $speedThreshold
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.speedThreshold) }
            .store(in: &cancellables)

        $speedUnit
            .sink { [weak self] in self?.userDefaults.set($0.rawValue, forKey: Keys.speedUnit) }
            .store(in: &cancellables)

        $startDurationSeconds
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.startDurationSeconds) }
            .store(in: &cancellables)

        $endDurationSeconds
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.endDurationSeconds) }
            .store(in: &cancellables)

        $minGpsAccuracyMeters
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.minGpsAccuracyMeters) }
            .store(in: &cancellables)

        $useGpsAccuracyFilter
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.useGpsAccuracyFilter) }
            .store(in: &cancellables)

        $autoStartLiveSession
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.autoStartLiveSession) }
            .store(in: &cancellables)

        $notificationsEnabled
            .sink { [weak self] in self?.userDefaults.set($0, forKey: Keys.notificationsEnabled) }
            .store(in: &cancellables)
    }

    private enum Keys {
        static let speedThreshold = "settings.speedThreshold"
        static let speedUnit = "settings.speedUnit"
        static let startDurationSeconds = "settings.startDurationSeconds"
        static let endDurationSeconds = "settings.endDurationSeconds"
        static let minGpsAccuracyMeters = "settings.minGpsAccuracyMeters"
        static let useGpsAccuracyFilter = "settings.useGpsAccuracyFilter"
        static let autoStartLiveSession = "settings.autoStartLiveSession"
        static let notificationsEnabled = "settings.notificationsEnabled"
    }
}
