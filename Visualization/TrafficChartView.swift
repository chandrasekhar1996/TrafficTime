import Charts
import SwiftUI

struct TrafficChartView: View {
    @EnvironmentObject private var repository: TrafficRepository

    var body: some View {
        let snapshot = repository.analyticsSnapshot()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SummaryCards(snapshot: snapshot)
                TrendSection(title: "Daily Trend", points: snapshot.dailyTrend, color: .blue)
                TrendSection(title: "Weekly Trend", points: snapshot.weeklyTrend, color: .indigo)
                TrendSection(title: "Monthly Trend", points: snapshot.monthlyTrend, color: .purple)
                TopAreasSection(areas: snapshot.topCongestedAreas)
                DistributionSection(title: "Hour of Day Distribution", points: snapshot.hourOfDayDistribution)
                DistributionSection(title: "Day of Week Distribution", points: snapshot.dayOfWeekDistribution)
            }
            .padding()
        }
    }
}

private struct SummaryCards: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Summary")
                .font(.headline)

            Text("Total lifetime traffic time: \(formatDuration(snapshot.lifetimeDurationSeconds))")
            Text("Average event duration: \(formatDuration(snapshot.averageEventDurationSeconds))")

            if let longest = snapshot.longestEvent {
                Text("Longest event: \(formatDuration(longest.summary.durationSeconds))")
                Text("Longest event start: \(longest.startTimestamp.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Longest event: No events recorded")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TrendSection: View {
    let title: String
    let points: [AnalyticsSnapshot.TimePoint]
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)

            if points.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Period", point.label),
                        y: .value("Hours", point.durationSeconds / 3600)
                    )
                    .foregroundStyle(color)

                    AreaMark(
                        x: .value("Period", point.label),
                        y: .value("Hours", point.durationSeconds / 3600)
                    )
                    .foregroundStyle(color.opacity(0.2))
                }
                .frame(height: 180)
            }
        }
    }
}

private struct TopAreasSection: View {
    let areas: [AnalyticsSnapshot.RankedMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Congested Routes / Areas")
                .font(.headline)

            if areas.isEmpty {
                Text("No congestion areas yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(areas) { area in
                    HStack {
                        Text(area.label)
                        Spacer()
                        Text(formatDuration(area.durationSeconds))
                            .bold()
                    }
                    Text("\(area.eventCount) event(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DistributionSection: View {
    let title: String
    let points: [AnalyticsSnapshot.TimePoint]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)

            if points.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Bucket", point.label),
                        y: .value("Hours", point.durationSeconds / 3600)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 180)
            }
        }
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds > 0 else { return "0m" }
    let hours = Int(seconds / 3600)
    let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
    if hours == 0 { return "\(minutes)m" }
    return "\(hours)h \(minutes)m"
}
