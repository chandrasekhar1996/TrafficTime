import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var speedThresholdMph: Double {
        didSet { UserDefaults.standard.set(speedThresholdMph, forKey: "speedThreshold") }
    }
    @Published var entryConfirmationSeconds: Double {
        didSet { UserDefaults.standard.set(entryConfirmationSeconds, forKey: "entryConfirmation") }
    }
    @Published var exitConfirmationSeconds: Double {
        didSet { UserDefaults.standard.set(exitConfirmationSeconds, forKey: "exitConfirmation") }
    }
    @Published var isTracking: Bool {
        didSet { UserDefaults.standard.set(isTracking, forKey: "isTracking") }
    }
    @Published var useKmh: Bool {
        didSet { UserDefaults.standard.set(useKmh, forKey: "useKmh") }
    }

    init() {
        let d = UserDefaults.standard
        speedThresholdMph      = d.object(forKey: "speedThreshold")      as? Double ?? 50.0
        entryConfirmationSeconds = d.object(forKey: "entryConfirmation") as? Double ?? 25.0
        exitConfirmationSeconds  = d.object(forKey: "exitConfirmation")  as? Double ?? 30.0
        isTracking               = d.object(forKey: "isTracking")        as? Bool   ?? true
        useKmh                   = d.object(forKey: "useKmh")            as? Bool   ?? false
    }

    var speedThresholdDisplay: Double {
        useKmh ? speedThresholdMph * 1.60934 : speedThresholdMph
    }

    var speedUnit: String { useKmh ? "km/h" : "mph" }
}
