import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @AppStorage("appearanceMode") private var appearanceMode = 0 // 0 = system, 1 = light, 2 = dark

    var body: some View {
        Group {
            if authService.isLoading {
                // Initial auth state check
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(Theme.accentTeal)
                }
            } else if authService.isAuthenticated {
                TabView {
                    Tab("Entries", systemImage: "list.bullet.rectangle.portrait") {
                        EntriesTabView()
                    }
                    Tab("Stats", systemImage: "chart.pie") {
                        StatsTabView()
                    }
                    Tab("Map", systemImage: "map") {
                        MapTabView()
                    }
                    Tab("Settings", systemImage: "gearshape") {
                        SettingsTabView()
                    }
                }
                .tint(Theme.accentTeal)
            } else {
                LoginView()
            }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(appearanceMode == 1 ? .light : appearanceMode == 2 ? .dark : nil)
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.container)
        .environment(AuthService())
        .environment(FirestoreService())
}
