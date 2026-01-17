//
//  ContentView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

enum AppColorScheme: String, CaseIterable {
    case system
    case light
    case dark

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
    @AppStorage("selectedProductId") private var selectedProductId: String = "BTC-USD"
    @AppStorage("productIds") private var productIdsData: String = "BTC-USD,ETH-USD,XRP-USD"
    @State private var selectedTab: String = "metrics"
    @StateObject private var algorithmManager = AlgorithmMetricsManager()
    @StateObject private var feeService = FeeService(accessToken: nil)
    @StateObject private var oauthManager = OAuthManager()
    
    private var productIds: [String] {
        get {
            let ids = productIdsData.split(separator: ",").map(String.init)
            // Ensure we have at least default products
            return ids.isEmpty ? ["BTC-USD", "ETH-USD", "XRP-USD"] : ids
        }
        nonmutating set {
            productIdsData = newValue.joined(separator: ",")
            // Ensure selectedProductId is still valid
            if !newValue.contains(selectedProductId) {
                selectedProductId = newValue.first ?? "BTC-USD"
            }
        }
    }

    var body: some View {
        TabView {
            Tab("Metrics", systemImage: "chart.line.uptrend.xyaxis") {
                MetricsView(
                    algorithmManager: algorithmManager,
                    selectedProductId: $selectedProductId,
                    productIds: Binding(
                        get: { productIds },
                        set: { productIds = $0 }
                    ),
                    feeService: feeService
                )
            }
            Tab("Simulation", systemImage: "chart.bar.xaxis") {
                SimulationViewWrapper(
                    algorithmManager: algorithmManager,
                    selectedProductId: $selectedProductId,
                    productIds: Binding(
                        get: { productIds },
                        set: { productIds = $0 }
                    ),
                    feeService: feeService
                )
            }
            Tab("Orders", systemImage: "list.bullet.rectangle") {
                OrdersView()
            }
            Tab("Settings", systemImage: "gear.circle.fill") {
                SettingsView()
            }
        }
        .preferredColorScheme(appColorScheme.colorScheme)
        .onAppear {
            oauthManager.loadTokens()
            fetchFeeDataOnce()
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            if newToken != nil {
                fetchFeeDataOnce()
            } else {
                feeService.reset()
            }
        }
        .onChange(of: productIds) { _, newIds in
            // Ensure selectedProductId is still in the list
            if !newIds.contains(selectedProductId) {
                selectedProductId = newIds.first ?? "BTC-USD"
            }
        }
    }
    
    private func fetchFeeDataOnce() {
        guard let token = oauthManager.accessToken else {
            return
        }
        
        feeService.updateToken(token)
        feeService.setTokenRefreshHandler { [weak oauthManager] in
            guard let oauthManager = oauthManager else { return nil }
            let success = await oauthManager.refreshAccessToken()
            return success ? oauthManager.accessToken : nil
        }
        
        Task {
            await feeService.fetchTransactionSummary(productType: "SPOT")
        }
    }
}

#Preview {
    ContentView()
}
