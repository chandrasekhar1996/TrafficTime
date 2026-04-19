import CoreLocation
import Foundation
import MapKit

struct MapInsightFilters {
    enum DateWindow: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case last30Days = "Last 30 Days"

        var id: String { rawValue }
    }

    enum DayType: String, CaseIterable, Identifiable {
        case all = "All Days"
        case weekday = "Weekday"
        case weekend = "Weekend"

        var id: String { rawValue }
    }

    enum TimeOfDay: String, CaseIterable, Identifiable {
        case all = "Any Time"
        case morning = "Morning"
        case midday = "Midday"
        case evening = "Evening"
        case overnight = "Overnight"

        var id: String { rawValue }
    }

    var dateWindow: DateWindow = .allTime
    var dayType: DayType = .all
    var timeOfDay: TimeOfDay = .all
}

struct MapInsightLayerState {
    var showsSegments = true
    var showsHotspots = true
    var showsCorridors = false
}

struct TrafficCellAggregation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let totalDurationSeconds: TimeInterval
    let eventCount: Int
    let averageSpeedMph: Double
}

struct CorridorAggregation: Identifiable {
    let id: String
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let totalDurationSeconds: TimeInterval
    let eventCount: Int
    let averageSpeedMph: Double
}

struct SegmentInsight: Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let durationSeconds: TimeInterval
    let averageSpeedMph: Double
    let eventCount: Int
}

enum MapSelection: Identifiable {
    case segment(SegmentInsight)
    case hotspot(TrafficCellAggregation)
    case corridor(CorridorAggregation)

    var id: String {
        switch self {
        case let .segment(segment):
            return "segment-\(segment.id.uuidString)"
        case let .hotspot(hotspot):
            return "hotspot-\(hotspot.id)"
        case let .corridor(corridor):
            return "corridor-\(corridor.id)"
        }
    }

    var title: String {
        switch self {
        case .segment:
            return "Traffic Segment"
        case .hotspot:
            return "Congestion Hotspot"
        case .corridor:
            return "Commute Corridor"
        }
    }

    var totalDurationSeconds: TimeInterval {
        switch self {
        case let .segment(segment):
            return segment.durationSeconds
        case let .hotspot(hotspot):
            return hotspot.totalDurationSeconds
        case let .corridor(corridor):
            return corridor.totalDurationSeconds
        }
    }

    var eventCount: Int {
        switch self {
        case let .segment(segment):
            return segment.eventCount
        case let .hotspot(hotspot):
            return hotspot.eventCount
        case let .corridor(corridor):
            return corridor.eventCount
        }
    }

    var averageSpeedMph: Double {
        switch self {
        case let .segment(segment):
            return segment.averageSpeedMph
        case let .hotspot(hotspot):
            return hotspot.averageSpeedMph
        case let .corridor(corridor):
            return corridor.averageSpeedMph
        }
    }
}

enum TrafficSpatialAggregation {
    static func filter(events: [TrafficEvent], filters: MapInsightFilters, calendar: Calendar = .current, now: Date = .now) -> [TrafficEvent] {
        events.filter { event in
            guard isInDateWindow(event: event, filters: filters, now: now) else { return false }
            guard matchesDayType(event: event, filters: filters, calendar: calendar) else { return false }
            return matchesTimeOfDay(event: event, filters: filters, calendar: calendar)
        }
    }

    static func segmentInsights(from events: [TrafficEvent]) -> [SegmentInsight] {
        events.map { event in
            SegmentInsight(
                id: event.id,
                coordinates: event.geometry.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                durationSeconds: event.summary.durationSeconds,
                averageSpeedMph: event.summary.averageSpeedMph,
                eventCount: 1
            )
        }
    }

    static func hotspotAggregations(from events: [TrafficEvent], cellSizeDegrees: Double = 0.01) -> [TrafficCellAggregation] {
        var cells: [GridCellKey: CellAccumulator] = [:]

        for event in events {
            let durationShare = event.summary.durationSeconds / Double(max(event.geometry.count, 1))
            for point in event.geometry {
                let key = GridCellKey(latitude: point.latitude, longitude: point.longitude, cellSizeDegrees: cellSizeDegrees)
                var current = cells[key] ?? CellAccumulator()
                current.totalDurationSeconds += durationShare
                current.eventCount += 1
                current.totalWeightedSpeed += event.summary.averageSpeedMph * durationShare
                cells[key] = current
            }
        }

        return cells.map { key, value in
            let speed = value.totalDurationSeconds > 0 ? value.totalWeightedSpeed / value.totalDurationSeconds : 0
            return TrafficCellAggregation(
                id: "\(key.latitudeIndex)-\(key.longitudeIndex)",
                coordinate: key.centerCoordinate,
                totalDurationSeconds: value.totalDurationSeconds,
                eventCount: value.eventCount,
                averageSpeedMph: speed
            )
        }
        .sorted { $0.totalDurationSeconds > $1.totalDurationSeconds }
    }

    static func corridorAggregations(from events: [TrafficEvent]) -> [CorridorAggregation] {
        var corridors: [CorridorKey: CorridorAccumulator] = [:]

        for event in events {
            guard let first = event.geometry.first,
                  let last = event.geometry.last else { continue }

            let start = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            let end = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
            let key = CorridorKey(from: start, to: end)

            var current = corridors[key] ?? CorridorAccumulator(from: key.fromCenter, to: key.toCenter)
            current.totalDurationSeconds += event.summary.durationSeconds
            current.eventCount += 1
            current.totalWeightedSpeed += event.summary.averageSpeedMph * event.summary.durationSeconds
            corridors[key] = current
        }

        return corridors.map { key, value in
            let speed = value.totalDurationSeconds > 0 ? value.totalWeightedSpeed / value.totalDurationSeconds : 0
            return CorridorAggregation(
                id: key.id,
                from: value.from,
                to: value.to,
                totalDurationSeconds: value.totalDurationSeconds,
                eventCount: value.eventCount,
                averageSpeedMph: speed
            )
        }
        .sorted { $0.totalDurationSeconds > $1.totalDurationSeconds }
    }

    private static func isInDateWindow(event: TrafficEvent, filters: MapInsightFilters, now: Date) -> Bool {
        switch filters.dateWindow {
        case .allTime:
            return true
        case .last30Days:
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return true }
            return event.endTimestamp >= cutoff
        }
    }

    private static func matchesDayType(event: TrafficEvent, filters: MapInsightFilters, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: event.startTimestamp)
        let isWeekend = weekday == 1 || weekday == 7

        switch filters.dayType {
        case .all:
            return true
        case .weekday:
            return !isWeekend
        case .weekend:
            return isWeekend
        }
    }

    private static func matchesTimeOfDay(event: TrafficEvent, filters: MapInsightFilters, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: event.startTimestamp)
        switch filters.timeOfDay {
        case .all:
            return true
        case .morning:
            return (5..<11).contains(hour)
        case .midday:
            return (11..<16).contains(hour)
        case .evening:
            return (16..<21).contains(hour)
        case .overnight:
            return hour >= 21 || hour < 5
        }
    }
}

private struct GridCellKey: Hashable {
    let latitudeIndex: Int
    let longitudeIndex: Int
    let cellSizeDegrees: Double

    init(latitude: Double, longitude: Double, cellSizeDegrees: Double) {
        self.cellSizeDegrees = cellSizeDegrees
        latitudeIndex = Int(floor(latitude / cellSizeDegrees))
        longitudeIndex = Int(floor(longitude / cellSizeDegrees))
    }

    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (Double(latitudeIndex) + 0.5) * cellSizeDegrees,
            longitude: (Double(longitudeIndex) + 0.5) * cellSizeDegrees
        )
    }
}

private struct CorridorKey: Hashable {
    let fromLatIndex: Int
    let fromLonIndex: Int
    let toLatIndex: Int
    let toLonIndex: Int
    private let cellSizeDegrees: Double = 0.02

    init(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        func index(_ value: Double) -> Int { Int(floor(value / 0.02)) }

        let fromIndices = (index(from.latitude), index(from.longitude))
        let toIndices = (index(to.latitude), index(to.longitude))

        if fromIndices <= toIndices {
            fromLatIndex = fromIndices.0
            fromLonIndex = fromIndices.1
            toLatIndex = toIndices.0
            toLonIndex = toIndices.1
        } else {
            fromLatIndex = toIndices.0
            fromLonIndex = toIndices.1
            toLatIndex = fromIndices.0
            toLonIndex = fromIndices.1
        }
    }

    var id: String { "\(fromLatIndex)-\(fromLonIndex)-\(toLatIndex)-\(toLonIndex)" }

    var fromCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (Double(fromLatIndex) + 0.5) * cellSizeDegrees,
                               longitude: (Double(fromLonIndex) + 0.5) * cellSizeDegrees)
    }

    var toCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (Double(toLatIndex) + 0.5) * cellSizeDegrees,
                               longitude: (Double(toLonIndex) + 0.5) * cellSizeDegrees)
    }
}

private struct CellAccumulator {
    var totalDurationSeconds: TimeInterval = 0
    var eventCount = 0
    var totalWeightedSpeed: Double = 0
}

private struct CorridorAccumulator {
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    var totalDurationSeconds: TimeInterval = 0
    var eventCount = 0
    var totalWeightedSpeed: Double = 0
}
