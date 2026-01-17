//
//  SimulationViewWrapper.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Combine
import SwiftUI

struct SimulationViewWrapper: View {
    @ObservedObject var algorithmManager: AlgorithmMetricsManager
    @Binding var selectedProductId: String
    @Binding var productIds: [String]
    @ObservedObject var feeService: FeeService
    @StateObject private var oauthManager = OAuthManager()
    @State private var webSocketManagers: [String: WebSocketManager] = [:]
    @StateObject private var simulationManager = SimulatedOrderManager()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var orderManager: OrderExecutionManager?

    var body: some View {
        VStack(spacing: 0) {
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: .constant(false))
                Spacer()
            } else {
                ProductIdMenu(productIds: $productIds, selectedProductId: $selectedProductId)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if let manager = webSocketManagers[selectedProductId] {
                    SimulationView(
                        simulationManager: simulationManager,
                        algorithmManager: algorithmManager,
                        orderManager: orderManager,
                        webSocketManager: manager,
                        productId: selectedProductId
                    )
                    .onAppear {
                        observeManager(manager)
                        initializeOrderManager()
                        connectSimulationManager()
                    }
                } else {
                    ProgressView("Connecting...")
                }
            }
        }
        .onAppear {
            oauthManager.loadTokens()
            setupWebSocketManagers()
            connectSimulationManager()
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            if newToken != nil {
                setupWebSocketManagers()
                initializeOrderManager()
                connectSimulationManager()
            } else {
                for manager in webSocketManagers.values {
                    manager.disconnect()
                }
                webSocketManagers.removeAll()
                orderManager?.invalidateToken()
                orderManager = nil
                algorithmManager.reset()
                cancellables.removeAll()
            }
        }
        .onChange(of: productIds) { _, _ in
            setupWebSocketManagers()
        }
        .onChange(of: selectedProductId) { _, newProductId in
            if let token = oauthManager.accessToken,
               !newProductId.isEmpty,
               webSocketManagers[newProductId] == nil
            {
                webSocketManagers[newProductId] = WebSocketManager(accessToken: token, productId: newProductId)
            }

            algorithmManager.reset()
            if let manager = webSocketManagers[newProductId] {
                observeManager(manager)
            }
        }
    }

    private func connectSimulationManager() {
        if simulationManager.algorithmManager == nil {
            simulationManager.setAlgorithmManager(algorithmManager)
        }
        // Connect fee service to simulation manager
        simulationManager.feeService = feeService
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

    private func setupWebSocketManagers() {
        guard let token = oauthManager.accessToken else {
            webSocketManagers.removeAll()
            return
        }

        if !productIds.contains(selectedProductId) || selectedProductId.isEmpty {
            selectedProductId = productIds.first ?? ""
        }

        let productIdToSubscribe = selectedProductId.isEmpty ? (productIds.first ?? "") : selectedProductId
        if !productIdToSubscribe.isEmpty, webSocketManagers[productIdToSubscribe] == nil {
            webSocketManagers[productIdToSubscribe] = WebSocketManager(accessToken: token, productId: productIdToSubscribe)
        }

        let productIdSet = Set(productIds)
        let toRemove = webSocketManagers.keys.filter { !productIdSet.contains($0) }
        for productId in toRemove {
            webSocketManagers.removeValue(forKey: productId)
        }
    }

    private func observeManager(_ manager: WebSocketManager) {
        cancellables.removeAll()

        let algoMgr = algorithmManager
        let simMgr = simulationManager
        let prodId = selectedProductId

        manager.$orderbookSnapshot
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { snapshot in
                guard snapshot.midPrice != nil else { return }

                // Update algorithm metrics and generate suggestions
                algoMgr.processSnapshot(snapshot, productId: prodId)

                // Update simulation manager with snapshot - CRITICAL: pass productId to prevent cross-product updates
                simMgr.updateSnapshot(snapshot, productId: prodId)
            }
            .store(in: &cancellables)
    }
}
