import CoreLocation
import Foundation
import SQLite3

struct TrafficEventPoint: Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

struct TrafficEvent: Identifiable, Codable {
    let id: UUID
    let startTimestamp: Date
    let endTimestamp: Date
    let geometry: [TrafficEventPoint]
    let summary: TrafficEventSummary
}

struct AnalyticsSnapshot {
    struct TimePoint: Identifiable {
        let id = UUID()
        let label: String
        let durationSeconds: TimeInterval
    }

    struct RankedMetric: Identifiable {
        let id = UUID()
        let label: String
        let durationSeconds: TimeInterval
        let eventCount: Int
    }

    let lifetimeDurationSeconds: TimeInterval
    let dailyTrend: [TimePoint]
    let weeklyTrend: [TimePoint]
    let monthlyTrend: [TimePoint]
    let topCongestedAreas: [RankedMetric]
    let hourOfDayDistribution: [TimePoint]
    let dayOfWeekDistribution: [TimePoint]
    let longestEvent: TrafficEvent?
    let averageEventDurationSeconds: TimeInterval
}

final class TrafficRepository: ObservableObject {
    @Published private(set) var events: [TrafficEvent] = []

    private let store: SQLiteTrafficStore

    init() {
        self.store = SQLiteTrafficStore()
        self.events = (try? store.loadAllEvents()) ?? []
    }

    func save(event: TrafficEvent) {
        events.append(event)
        try? store.insert(event: event)
    }

    func clear() {
        events.removeAll()
        try? store.clearAll()
    }

    func analyticsSnapshot(calendar: Calendar = .current) -> AnalyticsSnapshot {
        let sortedEvents = events.sorted { $0.startTimestamp < $1.startTimestamp }
        let lifetime = sortedEvents.reduce(0) { $0 + $1.summary.durationSeconds }
        let daily = aggregateByDate(events: sortedEvents, component: .day, dateFormat: "MM/dd", calendar: calendar)
        let weekly = aggregateByWeek(events: sortedEvents, calendar: calendar)
        let monthly = aggregateByDate(events: sortedEvents, component: .month, dateFormat: "MMM yyyy", calendar: calendar)
        let topAreas = topCongestedAreas(events: sortedEvents)
        let hourly = hourOfDayDistribution(events: sortedEvents, calendar: calendar)
        let weekdays = dayOfWeekDistribution(events: sortedEvents, calendar: calendar)
        let longest = sortedEvents.max { $0.summary.durationSeconds < $1.summary.durationSeconds }
        let average = sortedEvents.isEmpty ? 0 : lifetime / Double(sortedEvents.count)

        return AnalyticsSnapshot(
            lifetimeDurationSeconds: lifetime,
            dailyTrend: daily,
            weeklyTrend: weekly,
            monthlyTrend: monthly,
            topCongestedAreas: topAreas,
            hourOfDayDistribution: hourly,
            dayOfWeekDistribution: weekdays,
            longestEvent: longest,
            averageEventDurationSeconds: average
        )
    }

    private func aggregateByDate(events: [TrafficEvent], component: Calendar.Component, dateFormat: String, calendar: Calendar) -> [AnalyticsSnapshot.TimePoint] {
        var buckets: [Date: TimeInterval] = [:]
        for event in events {
            guard let date = calendar.dateInterval(of: component, for: event.startTimestamp)?.start else { continue }
            buckets[date, default: 0] += event.summary.durationSeconds
        }

        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat

        return buckets.keys.sorted().map { date in
            AnalyticsSnapshot.TimePoint(label: formatter.string(from: date), durationSeconds: buckets[date] ?? 0)
        }
    }

    private func aggregateByWeek(events: [TrafficEvent], calendar: Calendar) -> [AnalyticsSnapshot.TimePoint] {
        var buckets: [Date: TimeInterval] = [:]
        for event in events {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: event.startTimestamp)?.start else { continue }
            buckets[weekStart, default: 0] += event.summary.durationSeconds
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        return buckets.keys.sorted().map { weekStart in
            AnalyticsSnapshot.TimePoint(label: "Wk of \(formatter.string(from: weekStart))", durationSeconds: buckets[weekStart] ?? 0)
        }
    }

    private func hourOfDayDistribution(events: [TrafficEvent], calendar: Calendar) -> [AnalyticsSnapshot.TimePoint] {
        var buckets = Array(repeating: 0.0, count: 24)
        for event in events {
            let hour = calendar.component(.hour, from: event.startTimestamp)
            guard (0..<24).contains(hour) else { continue }
            buckets[hour] += event.summary.durationSeconds
        }

        return buckets.enumerated().map { index, value in
            AnalyticsSnapshot.TimePoint(label: String(format: "%02d:00", index), durationSeconds: value)
        }
    }

    private func dayOfWeekDistribution(events: [TrafficEvent], calendar: Calendar) -> [AnalyticsSnapshot.TimePoint] {
        var buckets = Array(repeating: 0.0, count: 7)
        for event in events {
            let weekday = calendar.component(.weekday, from: event.startTimestamp)
            let index = max(0, min(6, weekday - 1))
            buckets[index] += event.summary.durationSeconds
        }

        let formatter = DateFormatter()
        let names = formatter.weekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names.enumerated().map { idx, name in
            AnalyticsSnapshot.TimePoint(label: name, durationSeconds: buckets[idx])
        }
    }

    private func topCongestedAreas(events: [TrafficEvent], gridSize: Double = 0.02) -> [AnalyticsSnapshot.RankedMetric] {
        var buckets: [String: (duration: TimeInterval, count: Int)] = [:]

        for event in events {
            guard let first = event.geometry.first else { continue }
            let lat = Int(floor(first.latitude / gridSize))
            let lon = Int(floor(first.longitude / gridSize))
            let key = "\(lat),\(lon)"
            let label = "Cell \(lat), \(lon)"
            let current = buckets[label] ?? (0, 0)
            buckets[label] = (current.duration + event.summary.durationSeconds, current.count + 1)
        }

        return buckets
            .map { label, value in
                AnalyticsSnapshot.RankedMetric(label: label, durationSeconds: value.duration, eventCount: value.count)
            }
            .sorted { $0.durationSeconds > $1.durationSeconds }
            .prefix(5)
            .map { $0 }
    }
}

private final class SQLiteTrafficStore {
    private var db: OpaquePointer?

    init(filename: String = "traffic_events.sqlite") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbURL = directory.appendingPathComponent(filename)

        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            db = nil
            return
        }

        createSchemaIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func insert(event: TrafficEvent) throws {
        guard let db else { return }

        try execute(sql: "BEGIN TRANSACTION;")

        let insertEventSQL = """
        INSERT OR REPLACE INTO traffic_events
        (id, start_ts, end_ts, duration_seconds, avg_speed_mph, min_speed_mph, max_speed_mph, sample_count,
         start_lat, start_lon, end_lat, end_lon)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, insertEventSQL, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        let points = event.geometry
        let startPoint = points.first
        let endPoint = points.last

        sqlite3_bind_text(stmt, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, event.startTimestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 3, event.endTimestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 4, event.summary.durationSeconds)
        sqlite3_bind_double(stmt, 5, event.summary.averageSpeedMph)
        sqlite3_bind_double(stmt, 6, event.summary.minimumSpeedMph)
        sqlite3_bind_double(stmt, 7, event.summary.maximumSpeedMph)
        sqlite3_bind_int(stmt, 8, Int32(event.summary.sampleCount))
        sqlite3_bind_double(stmt, 9, startPoint?.latitude ?? 0)
        sqlite3_bind_double(stmt, 10, startPoint?.longitude ?? 0)
        sqlite3_bind_double(stmt, 11, endPoint?.latitude ?? 0)
        sqlite3_bind_double(stmt, 12, endPoint?.longitude ?? 0)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            try execute(sql: "ROLLBACK;")
            return
        }

        try execute(sql: "DELETE FROM traffic_event_points WHERE event_id = '\(event.id.uuidString)';")

        let insertPointSQL = "INSERT INTO traffic_event_points (event_id, seq, lat, lon) VALUES (?, ?, ?, ?);"
        var pointStmt: OpaquePointer?
        sqlite3_prepare_v2(db, insertPointSQL, -1, &pointStmt, nil)
        defer { sqlite3_finalize(pointStmt) }

        for (index, point) in event.geometry.enumerated() {
            sqlite3_bind_text(pointStmt, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(pointStmt, 2, Int32(index))
            sqlite3_bind_double(pointStmt, 3, point.latitude)
            sqlite3_bind_double(pointStmt, 4, point.longitude)

            guard sqlite3_step(pointStmt) == SQLITE_DONE else {
                sqlite3_reset(pointStmt)
                continue
            }
            sqlite3_reset(pointStmt)
            sqlite3_clear_bindings(pointStmt)
        }

        try execute(sql: "COMMIT;")
    }

    func loadAllEvents() throws -> [TrafficEvent] {
        guard let db else { return [] }

        let sql = """
        SELECT id, start_ts, end_ts, duration_seconds, avg_speed_mph, min_speed_mph, max_speed_mph, sample_count
        FROM traffic_events
        ORDER BY start_ts ASC;
        """

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        var events: [TrafficEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let id = UUID(uuidString: String(cString: idPtr)) else { continue }

            let event = TrafficEvent(
                id: id,
                startTimestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                endTimestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                geometry: loadPoints(for: id),
                summary: TrafficEventSummary(
                    averageSpeedMph: sqlite3_column_double(stmt, 4),
                    minimumSpeedMph: sqlite3_column_double(stmt, 5),
                    maximumSpeedMph: sqlite3_column_double(stmt, 6),
                    sampleCount: Int(sqlite3_column_int(stmt, 7)),
                    durationSeconds: sqlite3_column_double(stmt, 3)
                )
            )
            events.append(event)
        }

        return events
    }

    func clearAll() throws {
        try execute(sql: "DELETE FROM traffic_event_points;")
        try execute(sql: "DELETE FROM traffic_events;")
    }

    private func loadPoints(for eventID: UUID) -> [TrafficEventPoint] {
        guard let db else { return [] }

        let sql = "SELECT lat, lon FROM traffic_event_points WHERE event_id = ? ORDER BY seq ASC;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (eventID.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        var points: [TrafficEventPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            points.append(TrafficEventPoint(latitude: sqlite3_column_double(stmt, 0), longitude: sqlite3_column_double(stmt, 1)))
        }

        return points
    }

    private func createSchemaIfNeeded() {
        try? execute(sql: """
        CREATE TABLE IF NOT EXISTS traffic_events (
            id TEXT PRIMARY KEY,
            start_ts REAL NOT NULL,
            end_ts REAL NOT NULL,
            duration_seconds REAL NOT NULL,
            avg_speed_mph REAL NOT NULL,
            min_speed_mph REAL NOT NULL,
            max_speed_mph REAL NOT NULL,
            sample_count INTEGER NOT NULL,
            start_lat REAL,
            start_lon REAL,
            end_lat REAL,
            end_lon REAL
        );
        """)

        try? execute(sql: """
        CREATE TABLE IF NOT EXISTS traffic_event_points (
            event_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            PRIMARY KEY (event_id, seq),
            FOREIGN KEY(event_id) REFERENCES traffic_events(id) ON DELETE CASCADE
        );
        """)

        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_traffic_events_start_ts ON traffic_events(start_ts);")
        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_traffic_events_end_ts ON traffic_events(end_ts);")
        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_traffic_events_start_location ON traffic_events(start_lat, start_lon);")
        try? execute(sql: "CREATE INDEX IF NOT EXISTS idx_traffic_points_location ON traffic_event_points(lat, lon);")
    }

    private func execute(sql: String) throws {
        guard let db else { return }
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
