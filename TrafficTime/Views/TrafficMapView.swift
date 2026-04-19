import SwiftUI
import MapKit

struct TrafficMapView: View {
    @EnvironmentObject var store: SessionStore
    @State private var selectedPeriod: StatsPeriod = .allTime

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker
                HeatMapView(points: filteredPoints)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottomTrailing) { legend }
            }
            .navigationTitle("Traffic Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(StatsPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var filteredPoints: [TrafficPoint] {
        store.sessions
            .filter { selectedPeriod.contains($0.startTime) }
            .flatMap { $0.points }
    }

    private var legend: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Traffic Density").font(.caption2).foregroundColor(.secondary)
            HStack(spacing: 4) {
                ForEach([Color.yellow, .orange, .red], id: \.self) { c in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(c.opacity(0.6))
                        .frame(width: 20, height: 12)
                }
            }
            HStack {
                Text("Low").font(.caption2)
                Spacer()
                Text("High").font(.caption2)
            }
            .frame(width: 72)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }
}

// MARK: - MapKit Bridge

struct HeatMapView: UIViewRepresentable {
    let points: [TrafficPoint]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.mapType = .mutedStandard
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard !points.isEmpty else { return }

        let grid = buildGrid(from: points)
        let maxCount = grid.values.max() ?? 1

        for (cell, count) in grid {
            let circle = HeatCircle(
                center: CLLocationCoordinate2D(latitude: cell.lat, longitude: cell.lng),
                radius: 120
            )
            circle.normalizedIntensity = Double(count) / Double(maxCount)
            map.addOverlay(circle, level: .aboveRoads)
        }

        fitMap(map, to: points)
    }

    private func fitMap(_ map: MKMapView, to pts: [TrafficPoint]) {
        let lats = pts.map { $0.latitude }
        let lngs = pts.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.02, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.02, (maxLng - minLng) * 1.4)
        )
        map.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
    }

    // Grid cell at ~100 m resolution (0.001° ≈ 111 m)
    struct Cell: Hashable {
        let lat: Double
        let lng: Double
        init(_ coord: CLLocationCoordinate2D) {
            lat = (coord.latitude  * 1000).rounded() / 1000
            lng = (coord.longitude * 1000).rounded() / 1000
        }
    }

    private func buildGrid(from pts: [TrafficPoint]) -> [Cell: Int] {
        var grid = [Cell: Int]()
        for p in pts { grid[Cell(p.coordinate), default: 0] += 1 }
        return grid
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let heat = overlay as? HeatCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKCircleRenderer(circle: heat)
            let i = heat.normalizedIntensity
            if i < 0.33 {
                r.fillColor = UIColor.systemYellow.withAlphaComponent(0.35)
            } else if i < 0.66 {
                r.fillColor = UIColor.systemOrange.withAlphaComponent(0.45)
            } else {
                r.fillColor = UIColor.systemRed.withAlphaComponent(0.55)
            }
            r.strokeColor = .clear
            return r
        }
    }
}

final class HeatCircle: MKCircle {
    var normalizedIntensity: Double = 0.5
}
