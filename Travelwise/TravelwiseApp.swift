//
//  TravelwiseApp.swift
//  Travelwise
//
//  Created by John on 2026-03-16.
//

import SwiftUI
import SwiftData

@main
struct TravelwiseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, Expense.self])
    }
}
