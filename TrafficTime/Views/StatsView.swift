import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: SessionStore
    @State private var chartTab: ChartTab = .daily

    enum ChartTab: String, CaseIterable {
        case daily   = "Daily"
        case hourly  = "Hour"
        case weekday = "Weekday"
        case monthly = "Monthly"
        case log     = "Log"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryGrid
                    Picker("Chart", selection: $chartTab) {
                        ForEach(ChartTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    chartContent
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
        }
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard("Today",      store.totalDuration(for: .today),     .orange)
            summaryCard("This Week",  store.totalDuration(for: .thisWeek),  .blue)
            summaryCard("This Month", store.totalDuration(for: .thisMonth), .green)
            summaryCard("All Time",   store.totalDuration,                  .purple)
        }
        .padding(.horizontal)
    }

    private func summaryCard(_ title: String, _ duration: TimeInterval, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(fmt(duration)).font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(String(format: "%.1f hrs", duration / 3600)).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Charts

    @ViewBuilder
    private var chartContent: some View {
        switch chartTab {
        case .daily:   dailyChart
        case .hourly:  hourlyChart
        case .weekday: weekdayChart
        case .monthly: monthlyChart
        case .log:     sessionLog
        }
    }

    private var dailyChart: some View {
        let data = store.dailyDurations(days: 30)
        return chartCard(title: "Daily Traffic (Last 30 Days)", subtitle: "Minutes per day") {
            Chart(data) { stat in
                BarMark(x: .value("Date", stat.date, unit: .day),
                        y: .value("Min",  stat.minutes))
                    .foregroundStyle(barColor(stat.minutes))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let n = v.as(Double.self) { Text("\(Int(n))m") } } } }
            .frame(height: 200)
        }
    }

    private var hourlyChart: some View {
        let data = store.hourlyDistribution()
        return chartCard(title: "By Hour of Day", subtitle: "Total minutes at each hour") {
            Chart(data) { stat in
                BarMark(x: .value("Hour", stat.hour),
                        y: .value("Min",  stat.minutes))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue.opacity(0.6), .purple],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = v.as(Int.self) {
                            Text(h == 0 ? "12a" : h < 12 ? "\(h)a" : h == 12 ? "12p" : "\(h-12)p")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }

    private var weekdayChart: some View {
        let data = store.weekdayDistribution()
        return chartCard(title: "By Day of Week", subtitle: "Total minutes per weekday") {
            Chart(data) { stat in
                BarMark(x: .value("Day", stat.label),
                        y: .value("Min", stat.minutes))
                    .foregroundStyle(
                        LinearGradient(colors: [.teal, .blue],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if stat.minutes > 0 {
                            Text(fmt(stat.duration)).font(.system(size: 8)).foregroundColor(.secondary)
                        }
                    }
            }
            .frame(height: 200)
        }
    }

    private var monthlyChart: some View {
        let data = store.monthlyDurations(months: 12)
        return chartCard(title: "Monthly Trend", subtitle: "Last 12 months") {
            Chart(data) { stat in
                LineMark(x: .value("Month", stat.date, unit: .month),
                         y: .value("Min",   stat.minutes))
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Month", stat.date, unit: .month),
                         y: .value("Min",   stat.minutes))
                    .foregroundStyle(.red.opacity(0.15))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    private var sessionLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Sessions (\(store.sessions.count))")
                .font(.headline)
                .padding(.horizontal)
            if store.sessions.isEmpty {
                Text("No sessions recorded yet.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(store.sessions) { SessionRowView(session: $0).padding(.horizontal) }
            }
        }
    }

    // MARK: - Helpers

    private func chartCard<C: View>(title: String, subtitle: String, @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).padding(.horizontal)
                Text(subtitle).font(.caption).foregroundColor(.secondary).padding(.horizontal)
            }
            chart().padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func barColor(_ minutes: Double) -> Color {
        if minutes == 0 { return .gray.opacity(0.3) }
        if minutes < 15 { return .green }
        if minutes < 30 { return .yellow }
        if minutes < 60 { return .orange }
        return .red
    }

    private func fmt(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
