import SwiftUI

struct AppShellView: View {
    var body: some View {
        TabView {
            NavigationStack {
                LiveSessionView()
            }
            .tabItem {
                Label("Live", systemImage: "speedometer")
            }

            NavigationStack {
                MapInsightsView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }

            NavigationStack {
                AnalyticsView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
