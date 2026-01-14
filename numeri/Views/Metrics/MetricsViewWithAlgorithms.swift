//
//  MetricsViewWithAlgorithms.swift
//  numeri
//
//  Example integration showing how to use AlgorithmMetricsManager
//  This demonstrates the extensible architecture for algorithm metrics
//

import SwiftUI
import Combine

// This is an example of how to integrate AlgorithmMetricsManager
// You can replace MetricsView with this or merge the functionality

struct MetricsViewWithAlgorithms: View {
    @StateObject private var oauthManager = OAuthManager()
    @State private var productIds: [String] = ["BTC-USD", "ETH-USD", "XRP-USD"]
    @State private var selectedProductId: String = "BTC-USD"
    @State private var webSocketManagers: [String: WebSocketManager] = [:]
    @StateObject private var metricsCalculator = MetricsCalculator()
    @StateObject private var algorithmManager = AlgorithmMetricsManager()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            ProductIdMenu(productIds: $productIds, selectedProductId: $selectedProductId)
                .padding(.top)
                .padding(.bottom)
            
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: .constant(false))
                Spacer()
            } else {
                if let manager = webSocketManagers[selectedProductId] {
                    HStack(spacing: 12) {
                        MetricsSidebar(metricsCalculator: metricsCalculator)
                        
                        Spacer()
                            .frame(width: 20)
                        
                        OrderbookContentView(
                            webSocketManager: manager,
                            maxQuantity: maxQuantity(for: manager),
                            productId: selectedProductId
                        )
                        
                        // Toggle button for suggestions
                        if !algorithmManager.suggestions.isEmpty {
                            Button(action: { showSuggestions.toggle() }) {
                                VStack {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.title2)
                                    Text("\(algorithmManager.suggestions.count)")
                                        .font(.caption)
                                }
                                .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                    .onAppear {
                        observeManager(manager)
                    }
                } else {
                    ProgressView("Connecting...")
                }
            }
        }
        .onAppear {
            oauthManager.loadTokens()
            setupWebSocketManagers()
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            if newToken != nil {
                setupWebSocketManagers()
            } else {
                for manager in webSocketManagers.values {
                    manager.disconnect()
                }
                webSocketManagers.removeAll()
                metricsCalculator.reset()
                algorithmManager.reset()
                cancellables.removeAll()
            }
        }
        .onChange(of: productIds) { _, _ in
            setupWebSocketManagers()
        }
        .onChange(of: selectedProductId) { _, newProductId in
            // Create WebSocketManager for the newly selected product ID if it doesn't exist
            if let token = oauthManager.accessToken,
               !newProductId.isEmpty,
               webSocketManagers[newProductId] == nil {
                webSocketManagers[newProductId] = WebSocketManager(accessToken: token, productId: newProductId)
            }
            
            metricsCalculator.reset()
            algorithmManager.reset()
            if let manager = webSocketManagers[newProductId] {
                observeManager(manager)
            }
        }
        .sheet(isPresented: $showSuggestions) {
            NavigationView {
                OrderSuggestionsView(algorithmManager: algorithmManager)
                    .navigationTitle("Order Suggestions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showSuggestions = false
                            }
                        }
                    }
            }
        }
    }
    
    private func observeManager(_ manager: WebSocketManager) {
        cancellables.removeAll()
        
        // Subscribe to atomic orderbook snapshot for metrics calculator
        manager.$orderbookSnapshot
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [metricsCalculator, algorithmManager] snapshot in
                guard let midPrice = snapshot.midPrice else { return }
                
                // Update traditional metrics
                metricsCalculator.calculateMetrics(
                    bids: snapshot.bids,
                    offers: snapshot.offers,
                    currentPrice: midPrice,
                    latencyMs: snapshot.latencyMs
                )
                
                // Update algorithm metrics and generate suggestions
                algorithmManager.processSnapshot(snapshot, productId: selectedProductId)
            }
            .store(in: &cancellables)
    }
    
    private func setupWebSocketManagers() {
        guard let token = oauthManager.accessToken else {
            webSocketManagers.removeAll()
            return
        }
        
        // Ensure selectedProductId is valid
        if !productIds.contains(selectedProductId) || selectedProductId.isEmpty {
            selectedProductId = productIds.first ?? ""
        }
        
        // Only create WebSocketManager for the selected product ID if it doesn't exist
        let productIdToSubscribe = selectedProductId.isEmpty ? (productIds.first ?? "") : selectedProductId
        if !productIdToSubscribe.isEmpty && webSocketManagers[productIdToSubscribe] == nil {
            webSocketManagers[productIdToSubscribe] = WebSocketManager(accessToken: token, productId: productIdToSubscribe)
        }
        
        // Remove managers for product IDs that are no longer in the list
        let productIdSet = Set(productIds)
        let toRemove = webSocketManagers.keys.filter { !productIdSet.contains($0) }
        for productId in toRemove {
            webSocketManagers.removeValue(forKey: productId)
        }
    }
    
    private func maxQuantity(for manager: WebSocketManager) -> Double {
        let allEntries = manager.bids.getElements() + manager.offers.getElements()
        let quantities = allEntries.filter { $0.quantity > 0 }.map { $0.quantity }
        return quantities.max() ?? 1.0
    }
}

