import SwiftUI

struct TrafficChartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 42))
            Text("Analytics charts")
                .font(.headline)
            Text("Daily congestion trends and speed histograms will render here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
