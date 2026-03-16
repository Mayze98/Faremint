//
//  ContentView.swift
//  Travelwise
//
//  Created by John on 2026-03-16.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0 // 0 = system, 1 = light, 2 = dark

    var body: some View {
        TabView {
            Tab("Entries", systemImage: "list.bullet.rectangle.portrait") {
                EntriesTabView()
            }
            Tab("Stats", systemImage: "chart.pie") {
                StatsTabView()
            }
            Tab("Past Trips", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                PastTripsTabView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsTabView()
            }
        }
        .tint(Theme.accentTeal)
        .fontDesign(.rounded)
        .preferredColorScheme(appearanceMode == 1 ? .light : appearanceMode == 2 ? .dark : nil)
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.container)
}
