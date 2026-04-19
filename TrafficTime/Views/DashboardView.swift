import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var detector: TrafficDetector
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusRing
                    speedCard
                    periodStats
                    recentSessions
                }
                .padding()
            }
            .navigationTitle("TrafficTime")
        }
    }

    // MARK: - Status Ring

    private var statusRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
                .frame(width: 210, height: 210)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: ringProgress)

            VStack(spacing: 6) {
                if detector.isInTraffic {
                    Text(formatDuration(detector.currentSessionDuration))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("IN TRAFFIC")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .kerning(2)
                } else if detector.entryCountdown > 0 {
                    Text("\(Int(detector.entryCountdown * settings.entryConfirmationSeconds))s")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("DETECTING...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .kerning(2)
                } else {
                    Image(systemName: "car.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    Text("FREE FLOW")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .kerning(2)
                }
            }
        }
        .padding(.top, 8)
    }

    private var ringProgress: Double {
        if detector.isInTraffic { return 1.0 }
        return detector.entryCountdown
    }

    private var ringColor: Color {
        if detector.isInTraffic { return .red }
        return .orange
    }

    // MARK: - Speed Card

    private var speedCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Speed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(displaySpeed)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    Text(settings.speedUnit)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Threshold")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(settings.speedThresholdDisplay)) \(settings.speedUnit)")
                    .font(.title2)
                    .fontWeight(.semibold)
                speedIcon
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var displaySpeed: String {
        guard locationManager.currentSpeedMph >= 0 else { return "–" }
        let val = settings.useKmh ? locationManager.currentSpeedMph * 1.60934 : locationManager.currentSpeedMph
        return String(format: "%.0f", val)
    }

    private var speedIcon: some View {
        let inTrafficBySpeed = locationManager.currentSpeedMph >= 0 &&
                               locationManager.currentSpeedMph < settings.speedThresholdMph
        return Image(systemName: inTrafficBySpeed ? "tortoise.fill" : "hare.fill")
            .font(.title2)
            .foregroundColor(inTrafficBySpeed ? .red : .green)
    }

    // MARK: - Period Stats

    private var periodStats: some View {
        HStack(spacing: 12) {
            statTile("Today",     formatDuration(store.totalDuration(for: .today)),     "sun.max.fill",         .orange)
            statTile("This Week", formatDuration(store.totalDuration(for: .thisWeek)),  "calendar.badge.clock", .blue)
            statTile("All Time",  formatDuration(store.totalDuration),                  "infinity",             .purple)
        }
    }

    private func statTile(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value).font(.headline).fontWeight(.bold)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Recent Sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions").font(.headline)
            if store.sessions.isEmpty {
                Text("No traffic sessions yet.\nStart driving to begin tracking.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(store.sessions.prefix(5)) { SessionRowView(session: $0) }
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }
}

struct SessionRowView: View {
    let session: TrafficSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.startTime, style: .date).font(.subheadline).fontWeight(.medium)
                Text(session.startTime, style: .time).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(session.formattedDuration).font(.headline).foregroundColor(.red)
                Text("\(session.points.count) pts").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
