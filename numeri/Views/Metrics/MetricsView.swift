//
//  MetricsView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import Combine
import SwiftUI

struct MetricsView: View {
    @ObservedObject var algorithmManager: AlgorithmMetricsManager
    @Binding var selectedProductId: String
    @Binding var productIds: [String]
    @ObservedObject var feeService: FeeService
    @StateObject private var oauthManager = OAuthManager()
    @State private var webSocketManagers: [String: WebSocketManager] = [:]
    @StateObject private var metricsCalculator = MetricsCalculator()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var orderManager: OrderExecutionManager?
    @State private var expiredSuggestionTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: .constant(false))
                Spacer()
            } else {
                ProductIdMenu(productIds: $productIds, selectedProductId: $selectedProductId)
                    .padding(.top, TerminalTheme.paddingMedium)
                    .padding(.bottom, TerminalTheme.paddingSmall)
                    .padding(.horizontal, TerminalTheme.paddingXLarge)

                // Main content area
                if let manager = webSocketManagers[selectedProductId] {
                    VStack(spacing: 0) {
                        HStack(spacing: TerminalTheme.paddingMedium) {
                            // Metrics sidebar
                            ScrollView {
                                MetricsSidebar(metricsCalculator: metricsCalculator)
                                    .padding(.horizontal, TerminalTheme.paddingSmall)
                                    .padding(.vertical, TerminalTheme.paddingSmall)
                            }
                            .frame(minWidth: 200, maxWidth: 300)

                            // Orderbook
                            OrderbookContentView(
                                webSocketManager: manager,
                                maxQuantity: maxQuantity(for: manager),
                                productId: selectedProductId
                            )
                            .padding(.horizontal, TerminalTheme.paddingSmall)
                            .padding(.vertical, TerminalTheme.paddingSmall)
                            .frame(minWidth: 150, maxWidth: 220)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, TerminalTheme.paddingXLarge)
                        .padding(.vertical, TerminalTheme.paddingMedium)
                        .frame(maxHeight: .infinity)
                        .background(TerminalTheme.background)
                        .onAppear {
                            observeManager(manager)
                            initializeOrderManager()
                            startExpiredSuggestionTimer()
                        }
                        .onDisappear {
                            expiredSuggestionTimer?.invalidate()
                        }
                        
                        // Fee information at the bottom
                        FeeInfoView(feeService: feeService)
                            .padding(.horizontal, TerminalTheme.paddingXLarge)
                            .padding(.bottom, TerminalTheme.paddingMedium)
                    }
                } else {
                    VStack(spacing: TerminalTheme.paddingSmall) {
                        ProgressView()
                            .tint(TerminalTheme.cyan)
                        Text("CONNECTING TO MARKET DATA...")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                initializeOrderManager()
            } else {
                for manager in webSocketManagers.values {
                    manager.disconnect()
                }
                webSocketManagers.removeAll()
                orderManager?.invalidateToken()
                orderManager = nil
                metricsCalculator.reset()
                algorithmManager.reset()
                expiredSuggestionTimer?.invalidate()
                expiredSuggestionTimer = nil
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
               webSocketManagers[newProductId] == nil
            {
                webSocketManagers[newProductId] = WebSocketManager(accessToken: token, productId: newProductId)
            }

            metricsCalculator.reset()
            algorithmManager.reset()
            if let manager = webSocketManagers[newProductId] {
                observeManager(manager)
            }
        }
    }

    private func initializeOrderManager() {
        if orderManager == nil, let token = oauthManager.accessToken {
            orderManager = OrderExecutionManager(accessToken: token) { [weak oauthManager] in
                guard let oauthManager = oauthManager else { return nil }
                let success = await oauthManager.refreshAccessToken()
                return success ? oauthManager.accessToken : nil
            }
            Task {
                try? await orderManager?.fetchOrders()
            }
        }
    }

    private func updateMetrics() {
        guard let manager = webSocketManagers[selectedProductId] else { return }

        // Use atomic snapshot to ensure data consistency
        let snapshot = manager.orderbookSnapshot
        guard let midPrice = snapshot.midPrice else { return }

        metricsCalculator.calculateMetrics(
            bids: snapshot.bids,
            offers: snapshot.offers,
            currentPrice: midPrice,
            latencyMs: snapshot.latencyMs
        )
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
        if !productIdToSubscribe.isEmpty, webSocketManagers[productIdToSubscribe] == nil {
            webSocketManagers[productIdToSubscribe] = WebSocketManager(accessToken: token, productId: productIdToSubscribe)
        }

        // Remove managers for product IDs that are no longer in the list
        let productIdSet = Set(productIds)
        let toRemove = webSocketManagers.keys.filter { !productIdSet.contains($0) }
        for productId in toRemove {
            webSocketManagers.removeValue(forKey: productId)
        }
    }

    private func observeManager(_ manager: WebSocketManager) {
        cancellables.removeAll()

        // Subscribe to atomic orderbook snapshot to ensure bids and offers are always from the same point in time
        // Use a shorter debounce (50ms) for metrics to get more accurate readings while still batching rapid updates
        let calc = metricsCalculator
        let algoMgr = algorithmManager
        let ordMgr = orderManager
        let prodId = selectedProductId
        let wsMgrs = webSocketManagers

        manager.$orderbookSnapshot
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { snapshot in
                guard let midPrice = snapshot.midPrice else { return }

                // Update traditional metrics
                calc.calculateMetrics(
                    bids: snapshot.bids,
                    offers: snapshot.offers,
                    currentPrice: midPrice,
                    latencyMs: snapshot.latencyMs
                )

                // Update algorithm metrics and generate suggestions
                algoMgr.processSnapshot(snapshot, productId: prodId)

                // Check for expired suggestions and record as missed opportunities
                if let ordMgr = ordMgr {
                    // Only record and remove truly expired suggestions (target close time passed)
                    let expired = algoMgr.getExpiredSuggestions()
                    for suggestion in expired {
                        ordMgr.recordMissedOpportunity(suggestion)
                    }
                    algoMgr.removeExpiredSuggestions()

                    // Update PnL for missed opportunities that have reached their target close time
                    if let snapshot = wsMgrs[prodId]?.orderbookSnapshot,
                       let currentPrice = snapshot.midPrice
                    {
                        for order in ordMgr.recentOrders where order.source == .missed {
                            if let targetTime = order.targetCloseTime,
                               Date() >= targetTime,
                               order.actualPnL == nil
                            {
                                ordMgr.updateMissedOpportunityPnL(orderId: order.id, currentPrice: currentPrice)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func checkForExpiredSuggestions() {
        guard let orderManager = orderManager else { return }

        let expired = algorithmManager.getExpiredSuggestions()
        for suggestion in expired {
            // Record as missed opportunity
            orderManager.recordMissedOpportunity(suggestion)
        }

        // Remove expired from active suggestions
        algorithmManager.removeExpiredSuggestions()

        // Update PnL for missed opportunities that have reached their target close time
        if let snapshot = webSocketManagers[selectedProductId]?.orderbookSnapshot,
           let currentPrice = snapshot.midPrice
        {
            for order in orderManager.recentOrders where order.source == .missed {
                if let targetTime = order.targetCloseTime,
                   Date() >= targetTime,
                   order.actualPnL == nil
                {
                    orderManager.updateMissedOpportunityPnL(orderId: order.id, currentPrice: currentPrice)
                }
            }
        }
    }

    private func startExpiredSuggestionTimer() {
        // Check every 30 seconds for expired suggestions
        expiredSuggestionTimer?.invalidate()

        let algoMgr = algorithmManager
        let ordMgr = orderManager
        let prodId = selectedProductId
        let wsMgrs = webSocketManagers

        expiredSuggestionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            guard let ordMgr = ordMgr else { return }

            // Only record and remove truly expired suggestions (target close time passed)
            let expired = algoMgr.getExpiredSuggestions()
            for suggestion in expired {
                ordMgr.recordMissedOpportunity(suggestion)
            }
            algoMgr.removeExpiredSuggestions()

            // Update PnL for missed opportunities that have reached their target close time
            if let snapshot = wsMgrs[prodId]?.orderbookSnapshot,
               let currentPrice = snapshot.midPrice
            {
                for order in ordMgr.recentOrders where order.source == .missed {
                    if let targetTime = order.targetCloseTime,
                       Date() >= targetTime,
                       order.actualPnL == nil
                    {
                        ordMgr.updateMissedOpportunityPnL(orderId: order.id, currentPrice: currentPrice)
                    }
                }
            }
        }

        if let timer = expiredSuggestionTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func maxQuantity(for manager: WebSocketManager) -> Double {
        let allEntries = manager.bids.getElements() + manager.offers.getElements()
        let quantities = allEntries.filter { $0.quantity > 0 }.map { $0.quantity }
        return quantities.max() ?? 1.0
    }
}
