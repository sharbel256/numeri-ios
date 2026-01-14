//
//  OrdersViewWithExecution.swift
//  numeri
//
//  Example view showing order execution integration
//

import SwiftUI

struct OrdersViewWithExecution: View {
    @StateObject private var oauthManager = OAuthManager()
    @State private var orderManager: OrderExecutionManager?
    @State private var showCredentialsAlert: Bool = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: $showCredentialsAlert)
            } else {
                if let manager = orderManager {
                    TabView(selection: $selectedTab) {
                        // Order History Tab
                        OrderHistoryView(orderManager: manager)
                            .tabItem {
                                Label("History", systemImage: "list.bullet.rectangle")
                            }
                            .tag(0)
                        
                        // Pending Orders Tab
                        PendingOrdersView(orderManager: manager)
                            .tabItem {
                                Label("Pending", systemImage: "clock")
                            }
                            .tag(1)
                    }
                } else {
                    ProgressView("Initializing...")
                        .onAppear {
                            initializeOrderManager()
                        }
                }
            }
        }
        .alert("Log in Required", isPresented: $showCredentialsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please go to the Settings tab to log in with Coinbase.")
        }
        .onAppear {
            oauthManager.loadTokens()
            initializeOrderManager()
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            if let token = newToken {
                orderManager = OrderExecutionManager(accessToken: token) { [weak oauthManager] in
                    guard let oauthManager = oauthManager else { return nil }
                    let success = await oauthManager.refreshAccessToken()
                    return success ? oauthManager.accessToken : nil
                }
                Task {
                    try? await orderManager?.fetchOrders()
                }
            } else {
                orderManager?.invalidateToken()
                orderManager = nil
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
}

struct PendingOrdersView: View {
    @ObservedObject var orderManager: OrderExecutionManager
    
    private var pendingOrders: [Order] {
        orderManager.getPendingOrders().sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            if pendingOrders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No pending orders")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Pending Orders")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingOrders) { order in
                            OrderCard(order: order, orderManager: orderManager)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Pending Orders")
            }
        }
    }
}

