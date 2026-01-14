import SwiftUI

struct OrdersView: View {
    @StateObject private var oauthManager = OAuthManager()
    @State private var orderManager: OrderExecutionManager?
    @State private var showCredentialsAlert = false
    @State private var isLoading = false
    @State private var selectedProductId: String? = nil
    
    var body: some View {
        VStack {
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: $showCredentialsAlert)
            } else if let manager = orderManager {
                VStack(spacing: 0) {
                    if !manager.canFetchOrders {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Showing locally tracked orders only. Re-authenticate in Settings to fetch all orders.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    HStack {
                        Text("Filter:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Product", selection: $selectedProductId) {
                            Text("All Products").tag(String?.none)
                            ForEach(availableProductIds(manager: manager), id: \.self) { productId in
                                Text(productId).tag(String?.some(productId))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProductId) { _, _ in
                            Task {
                                await refreshOrders()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    OrdersListView(
                        orders: combinedOrders(manager: manager),
                        orderManager: manager,
                        title: "Orders",
                        onRefresh: { await refreshOrders() }
                    )
                }
            } else {
                ProgressView("Loading orders...")
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
        .onChange(of: oauthManager.accessToken) { oldValue, newValue in
            if let token = newValue {
                orderManager = OrderExecutionManager(accessToken: token) { [weak oauthManager] in
                    guard let oauthManager = oauthManager else { return nil }
                    let success = await oauthManager.refreshAccessToken()
                    return success ? oauthManager.accessToken : nil
                }
                Task {
                    await refreshOrders()
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
                await refreshOrders()
            }
        }
    }
    
    private func refreshOrders() async {
        guard let manager = orderManager else { return }
        isLoading = true
        do {
            try await manager.fetchOrders(productId: selectedProductId)
        } catch {
        }
        isLoading = false
    }
    
    private func availableProductIds(manager: OrderExecutionManager) -> [String] {
        let allOrders = manager.getOpenOrders() + manager.getFilledOrders() + manager.getCanceledOrders()
        let productIds = Set(allOrders.map { $0.productId })
        return Array(productIds).sorted()
    }
    
    private func combinedOrders(manager: OrderExecutionManager) -> [Order] {
        // Get all orders
        let allOrders = manager.getOpenOrders() + manager.getFilledOrders() + manager.getCanceledOrders()
        
        // Filter by product if selected
        var filteredOrders = allOrders
        if let productId = selectedProductId {
            filteredOrders = filteredOrders.filter { $0.productId == productId }
        }
        
        // Sort: open orders first, then all others, both sorted by date (newest first)
        return filteredOrders.sorted { order1, order2 in
            let isOpen1 = order1.status == .open
            let isOpen2 = order2.status == .open
            
            // If one is open and the other isn't, open comes first
            if isOpen1 && !isOpen2 {
                return true
            }
            if !isOpen1 && isOpen2 {
                return false
            }
            
            // Otherwise, sort by date (newest first)
            return order1.createdAt > order2.createdAt
        }
    }
}

struct OrdersListView: View {
    let orders: [Order]
    @ObservedObject var orderManager: OrderExecutionManager
    let title: String
    let onRefresh: () async -> Void
    @State private var isCancelingAll = false
    
    var cancelableOrders: [Order] {
        orders.filter { [.pending, .open].contains($0.status) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !cancelableOrders.isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await cancelAllOrders()
                        }
                    }) {
                        HStack {
                            if isCancelingAll {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text("Cancel All")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(isCancelingAll)
                    .padding()
                }
            }
            
            if orders.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No \(title.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
                .refreshable {
                    await onRefresh()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(orders) { order in
                            OrderCard(order: order, orderManager: orderManager)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .refreshable {
                    await onRefresh()
                }
            }
        }
        .navigationTitle(title)
    }
    
    private func cancelAllOrders() async {
        isCancelingAll = true
        let orderIds = cancelableOrders.map { $0.id }
        do {
            try await orderManager.cancelOrders(orderIds: orderIds)
        } catch {
        }
        isCancelingAll = false
    }
}

