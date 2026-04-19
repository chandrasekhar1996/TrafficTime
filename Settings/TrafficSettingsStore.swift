import Foundation

final class TrafficSettingsStore: ObservableObject {
    @Published var slowThreshold: Double = 8
    @Published var congestedThreshold: Double = 4
    @Published var stoppedThreshold: Double = 0.5
    @Published var autoStartLiveSession: Bool = true
}
