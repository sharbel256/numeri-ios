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
                OrdersViewContent(
                    orderManager: manager,
                    selectedProductId: $selectedProductId,
                    onRefresh: { await refreshOrders() }
                )
            } else {
                VStack(spacing: TerminalTheme.paddingSmall) {
                    ProgressView()
                        .tint(TerminalTheme.cyan)
                    Text("LOADING ORDERS...")
                        .font(TerminalTheme.monospaced(size: 10))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
            }
        }
        .background(TerminalTheme.background)
        .alert("LOGIN REQUIRED", isPresented: $showCredentialsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please go to the Settings tab to log in with Coinbase.")
        }
        .onAppear {
            oauthManager.loadTokens()
            initializeOrderManager()
        }
        .onChange(of: oauthManager.accessToken) { _, newValue in
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
        } catch {}
        isLoading = false
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
            if isOpen1, !isOpen2 {
                return true
            }
            if !isOpen1, isOpen2 {
                return false
            }

            // Otherwise, sort by date (newest first)
            return order1.createdAt > order2.createdAt
        }
    }
}

struct OrdersViewContent: View {
    @ObservedObject var orderManager: OrderExecutionManager
    @Binding var selectedProductId: String?
    let onRefresh: () async -> Void
    
    private var combinedOrders: [Order] {
        // Get all orders - this depends on orderManager.orders which is @Published
        let allOrders = orderManager.getOpenOrders() + orderManager.getFilledOrders() + orderManager.getCanceledOrders()

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
            if isOpen1, !isOpen2 {
                return true
            }
            if !isOpen1, isOpen2 {
                return false
            }

            // Otherwise, sort by date (newest first)
            return order1.createdAt > order2.createdAt
        }
    }
    
    private var availableProductIds: [String] {
        let allOrders = orderManager.getOpenOrders() + orderManager.getFilledOrders() + orderManager.getCanceledOrders()
        let productIds = Set(allOrders.map { $0.productId })
        return Array(productIds).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            if !orderManager.canFetchOrders {
                HStack {
                    Text("⚠")
                        .font(.system(size: 12))
                        .foregroundColor(TerminalTheme.amber)
                    Text("SHOWING LOCALLY TRACKED ORDERS ONLY. RE-AUTHENTICATE IN SETTINGS TO FETCH ALL ORDERS.")
                        .font(TerminalTheme.monospaced(size: 9))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
                .padding(TerminalTheme.paddingSmall)
                .background(TerminalTheme.amber.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(TerminalTheme.amber.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, TerminalTheme.paddingSmall)
                .padding(.top, TerminalTheme.paddingSmall)
            }

            HStack {
                Text("FILTER:")
                    .font(TerminalTheme.monospaced(size: 10))
                    .foregroundColor(TerminalTheme.textSecondary)
                Picker("Product", selection: $selectedProductId) {
                    Text("ALL PRODUCTS").tag(String?.none)
                    ForEach(availableProductIds, id: \.self) { productId in
                        Text(productId).tag(String?.some(productId))
                    }
                }
                .pickerStyle(.menu)
                .font(TerminalTheme.monospaced(size: 10))
                .onChange(of: selectedProductId) { _, _ in
                    Task {
                        await onRefresh()
                    }
                }
                Spacer()
            }
            .padding(.horizontal, TerminalTheme.paddingSmall)
            .padding(.top, TerminalTheme.paddingTiny)

            OrdersListView(
                orders: combinedOrders,
                orderManager: orderManager,
                title: "Orders",
                onRefresh: onRefresh
            )
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
                        HStack(spacing: TerminalTheme.paddingTiny) {
                            if isCancelingAll {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(TerminalTheme.red)
                            } else {
                                Text("✕")
                                    .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                            }
                            Text("CANCEL ALL")
                                .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                        }
                        .foregroundColor(TerminalTheme.red)
                        .padding(.horizontal, TerminalTheme.paddingMedium)
                        .padding(.vertical, TerminalTheme.paddingSmall)
                        .background(TerminalTheme.red.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.red, lineWidth: 1)
                        )
                    }
                    .disabled(isCancelingAll)
                    .padding(TerminalTheme.paddingSmall)
                }
            }

            if orders.isEmpty {
                ScrollView {
                    VStack(spacing: TerminalTheme.paddingSmall) {
                        Text("[]")
                            .font(TerminalTheme.monospaced(size: 30))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text("NO \(title.uppercased())")
                            .font(TerminalTheme.monospaced(size: 11, weight: .medium))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
                .refreshable {
                    await onRefresh()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: TerminalTheme.paddingSmall) {
                        ForEach(orders) { order in
                            OrderCard(order: order, orderManager: orderManager)
                        }
                    }
                    .padding(.horizontal, TerminalTheme.paddingSmall)
                    .padding(.vertical, TerminalTheme.paddingSmall)
                }
                .refreshable {
                    await onRefresh()
                }
            }
        }
        .background(TerminalTheme.background)
        .navigationTitle(title.uppercased())
    }

    private func cancelAllOrders() async {
        isCancelingAll = true
        let orderIds = cancelableOrders.map { $0.id }
        do {
            try await orderManager.cancelOrders(orderIds: orderIds)
        } catch {}
        isCancelingAll = false
    }
}
