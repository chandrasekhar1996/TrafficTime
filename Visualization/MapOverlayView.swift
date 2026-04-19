import MapKit
import SwiftUI

struct MapOverlayView: View {
    @EnvironmentObject private var repository: TrafficRepository

    @State private var filters = MapInsightFilters()
    @State private var layers = MapInsightLayerState()
    @State private var selectedInsight: MapSelection?

    private var filteredEvents: [TrafficEvent] {
        TrafficSpatialAggregation.filter(events: repository.events, filters: filters)
    }

    private var segmentInsights: [SegmentInsight] {
        TrafficSpatialAggregation.segmentInsights(from: filteredEvents)
    }

    private var hotspotInsights: [TrafficCellAggregation] {
        TrafficSpatialAggregation.hotspotAggregations(from: filteredEvents)
            .filter { $0.eventCount > 1 }
    }

    private var corridorInsights: [CorridorAggregation] {
        TrafficSpatialAggregation.corridorAggregations(from: filteredEvents)
            .filter { $0.eventCount > 1 }
    }

    var body: some View {
        VStack(spacing: 12) {
            filtersRow
            layerToggles

            TrafficInsightsMapView(
                segments: layers.showsSegments ? segmentInsights : [],
                hotspots: layers.showsHotspots ? hotspotInsights : [],
                corridors: layers.showsCorridors ? corridorInsights : [],
                selectedInsight: $selectedInsight
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            summaryRow
        }
        .padding()
        .sheet(item: $selectedInsight) { insight in
            InsightDetailSheet(selection: insight)
                .presentationDetents([.height(220)])
        }
    }

    private var filtersRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Window", selection: $filters.dateWindow) {
                ForEach(MapInsightFilters.DateWindow.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Picker("Day", selection: $filters.dayType) {
                    ForEach(MapInsightFilters.DayType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Picker("Time", selection: $filters.timeOfDay) {
                    ForEach(MapInsightFilters.TimeOfDay.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            .font(.caption)
        }
    }

    private var layerToggles: some View {
        HStack {
            Toggle("Segments", isOn: $layers.showsSegments)
            Toggle("Hotspots", isOn: $layers.showsHotspots)
            Toggle("Corridors", isOn: $layers.showsCorridors)
        }
        .toggleStyle(.button)
        .font(.caption)
    }

    private var summaryRow: some View {
        let totalSeconds = filteredEvents.reduce(0) { $0 + $1.summary.durationSeconds }

        return HStack {
            Label("\(filteredEvents.count) events", systemImage: "car.fill")
            Spacer()
            Label(formatDuration(totalSeconds), systemImage: "clock")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0m"
    }
}

private struct InsightDetailSheet: View {
    let selection: MapSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selection.title)
                .font(.headline)

            statRow(title: "Total traffic time", value: readableDuration(selection.totalDurationSeconds))
            statRow(title: "Event count", value: "\(selection.eventCount)")
            statRow(title: "Average speed", value: String(format: "%.1f mph", selection.averageSpeedMph))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func readableDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? "0s"
    }
}

private struct TrafficInsightsMapView: UIViewRepresentable {
    let segments: [SegmentInsight]
    let hotspots: [TrafficCellAggregation]
    let corridors: [CorridorAggregation]
    @Binding var selectedInsight: MapSelection?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .excludingAll

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tap)

        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyData(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TrafficInsightsMapView
        weak var mapView: MKMapView?

        private var overlayLookup: [ObjectIdentifier: MapSelection] = [:]
        private var hasSetInitialRegion = false

        init(parent: TrafficInsightsMapView) {
            self.parent = parent
        }

        func applyData(on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            overlayLookup.removeAll()

            for segment in parent.segments where segment.coordinates.count > 1 {
                let polyline = SegmentPolyline(segment: segment)
                mapView.addOverlay(polyline)
                overlayLookup[ObjectIdentifier(polyline)] = .segment(segment)
            }

            for corridor in parent.corridors {
                let polyline = CorridorPolyline(corridor: corridor)
                mapView.addOverlay(polyline)
                overlayLookup[ObjectIdentifier(polyline)] = .corridor(corridor)
            }

            mapView.addAnnotations(parent.hotspots.map(HotspotAnnotation.init))

            if !hasSetInitialRegion {
                zoomToFitData(on: mapView)
                hasSetInitialRegion = true
            }
        }

        private func zoomToFitData(on mapView: MKMapView) {
            let allCoords = parent.segments.flatMap(\.coordinates)
            guard !allCoords.isEmpty else { return }

            var minLat = allCoords[0].latitude
            var maxLat = allCoords[0].latitude
            var minLon = allCoords[0].longitude
            var maxLon = allCoords[0].longitude

            for coord in allCoords {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }

            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
                                       longitudeDelta: max((maxLon - minLon) * 1.5, 0.02))
            )
            mapView.setRegion(region, animated: false)
        }

        @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let mapView else { return }

            let point = recognizer.location(in: mapView)
            let mapPoint = MKMapPoint(mapView.convert(point, toCoordinateFrom: mapView))

            for overlay in mapView.overlays {
                guard let renderer = mapView.renderer(for: overlay) as? MKPolylineRenderer,
                      let path = renderer.path else { continue }

                let rendererPoint = renderer.point(for: mapPoint)
                let tapTarget = path.copy(strokingWithWidth: max(renderer.lineWidth + 14, 18), lineCap: .round, lineJoin: .round, miterLimit: 0)

                if tapTarget.contains(rendererPoint),
                   let selection = overlayLookup[ObjectIdentifier(overlay)] {
                    parent.selectedInsight = selection
                    return
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let hotspot = annotation as? HotspotAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

            view.annotation = hotspot
            view.markerTintColor = Self.tintColor(forDuration: hotspot.aggregation.totalDurationSeconds)
            view.glyphText = "\(hotspot.aggregation.eventCount)"
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            view.canShowCallout = false
            view.clusteringIdentifier = "hotspot"
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let hotspot = view.annotation as? HotspotAnnotation else { return }
            parent.selectedInsight = .hotspot(hotspot.aggregation)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let segment = overlay as? SegmentPolyline {
                let renderer = MKPolylineRenderer(overlay: segment)
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.lineWidth = 5
                renderer.strokeColor = Self.tintColor(forDuration: segment.segment.durationSeconds)
                return renderer
            }

            if let corridor = overlay as? CorridorPolyline {
                let renderer = MKPolylineRenderer(overlay: corridor)
                renderer.lineWidth = 7
                renderer.lineDashPattern = [8, 6]
                renderer.strokeColor = .systemIndigo.withAlphaComponent(0.8)
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        private static func tintColor(forDuration seconds: TimeInterval) -> UIColor {
            switch seconds {
            case ..<120:
                return .systemGreen
            case ..<420:
                return .systemYellow
            case ..<900:
                return .systemOrange
            default:
                return .systemRed
            }
        }
    }
}

private final class SegmentPolyline: MKPolyline {
    let segment: SegmentInsight

    init(segment: SegmentInsight) {
        self.segment = segment
        var coordinates = segment.coordinates
        super.init(coordinates: &coordinates, count: coordinates.count)
    }
}

private final class CorridorPolyline: MKPolyline {
    let corridor: CorridorAggregation

    init(corridor: CorridorAggregation) {
        self.corridor = corridor
        var coordinates = [corridor.from, corridor.to]
        super.init(coordinates: &coordinates, count: coordinates.count)
    }
}

private final class HotspotAnnotation: NSObject, MKAnnotation {
    let aggregation: TrafficCellAggregation
    let coordinate: CLLocationCoordinate2D

    init(aggregation: TrafficCellAggregation) {
        self.aggregation = aggregation
        coordinate = aggregation.coordinate
    }
}
