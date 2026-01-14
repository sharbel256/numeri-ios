//
//  ContentView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

enum AppColorScheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ContentView: View {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    @State private var selectedTab: String = "metrics"
    @StateObject private var algorithmManager = AlgorithmMetricsManager()
    
    var body: some View {
        TabView {
            Tab("Metrics", systemImage: "chart.line.uptrend.xyaxis") {
                MetricsView(algorithmManager: algorithmManager)
            }
            Tab("Suggestions", systemImage: "lightbulb.fill") {
                SuggestionsView(algorithmManager: algorithmManager)
            }
            .badge(algorithmManager.suggestions.count > 0 ? algorithmManager.suggestions.count : 0)
            Tab("Orders", systemImage: "chart.bar.xaxis.ascending") {
                OrdersView()
            }
            Tab("Settings", systemImage: "gear.circle.fill") {
                SettingsView(appColorScheme: $appColorScheme)
            }
        }
        .preferredColorScheme(appColorScheme.colorScheme)
    }
}

#Preview {
    ContentView()
}
