import Foundation

class SessionStore: ObservableObject {
    @Published var sessions: [TrafficSession] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("traffic_sessions.json")
        load()
    }

    func save(_ session: TrafficSession) {
        sessions.append(session)
        sessions.sort { $0.startTime > $1.startTime }
        persist()
    }

    func deleteAll() {
        sessions.removeAll()
        persist()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Aggregations

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    func totalDuration(for period: StatsPeriod) -> TimeInterval {
        sessions.filter { period.contains($0.startTime) }.reduce(0) { $0 + $1.duration }
    }

    func dailyDurations(days: Int = 30) -> [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).compactMap { offset -> DayStat? in
            guard let day  = cal.date(byAdding: .day, value: -offset, to: today),
                  let next = cal.date(byAdding: .day, value: 1, to: day) else { return nil }
            let total = sessions.filter { $0.startTime >= day && $0.startTime < next }
                                .reduce(0) { $0 + $1.duration }
            return DayStat(date: day, duration: total)
        }.reversed()
    }

    func hourlyDistribution() -> [HourStat] {
        var map = [Int: TimeInterval]()
        for s in sessions {
            let h = Calendar.current.component(.hour, from: s.startTime)
            map[h, default: 0] += s.duration
        }
        return (0..<24).map { HourStat(hour: $0, duration: map[$0, default: 0]) }
    }

    func weekdayDistribution() -> [WeekdayStat] {
        var map = [Int: TimeInterval]()
        for s in sessions {
            let w = Calendar.current.component(.weekday, from: s.startTime)
            map[w, default: 0] += s.duration
        }
        return (1...7).map { WeekdayStat(weekday: $0, duration: map[$0, default: 0]) }
    }

    func monthlyDurations(months: Int = 12) -> [MonthStat] {
        let cal = Calendar.current
        let now = Date()
        return (0..<months).compactMap { offset -> MonthStat? in
            guard let month = cal.date(byAdding: .month, value: -offset, to: now),
                  let start = cal.dateInterval(of: .month, for: month)?.start,
                  let end   = cal.dateInterval(of: .month, for: month)?.end else { return nil }
            let total = sessions.filter { $0.startTime >= start && $0.startTime < end }
                                .reduce(0) { $0 + $1.duration }
            return MonthStat(date: start, duration: total)
        }.reversed()
    }

    var allTrafficPoints: [TrafficPoint] { sessions.flatMap { $0.points } }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TrafficSession].self, from: data) else { return }
        sessions = decoded.sorted { $0.startTime > $1.startTime }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Supporting Types

enum StatsPeriod: String, CaseIterable {
    case today = "Today"
    case thisWeek = "Week"
    case thisMonth = "Month"
    case allTime = "All Time"

    func contains(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:     return cal.isDateInToday(date)
        case .thisWeek:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth: return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .allTime:   return true
        }
    }
}

struct DayStat: Identifiable {
    var id: Date { date }
    var date: Date
    var duration: TimeInterval
    var minutes: Double { duration / 60 }
}

struct HourStat: Identifiable {
    var id: Int { hour }
    var hour: Int
    var duration: TimeInterval
    var minutes: Double { duration / 60 }
    var label: String {
        if hour == 0 { return "12a" }
        if hour == 12 { return "12p" }
        return hour < 12 ? "\(hour)a" : "\(hour - 12)p"
    }
}

struct WeekdayStat: Identifiable {
    var id: Int { weekday }
    var weekday: Int
    var duration: TimeInterval
    var minutes: Double { duration / 60 }
    var label: String {
        ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][(weekday - 1) % 7]
    }
}

struct MonthStat: Identifiable {
    var id: Date { date }
    var date: Date
    var duration: TimeInterval
    var minutes: Double { duration / 60 }
    var label: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }
}
