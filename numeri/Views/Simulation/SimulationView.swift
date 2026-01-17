//
//  SimulationView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import SwiftUI

struct SimulationView: View {
    @ObservedObject var simulationManager: SimulatedOrderManager
    @ObservedObject var algorithmManager: AlgorithmMetricsManager
    let orderManager: OrderExecutionManager?
    let webSocketManager: WebSocketManager?
    let productId: String

    @State private var selectedTab: SimulationTab = .open
    @State private var selectedAlgorithm: String? = nil

    enum SimulationTab {
        case open
        case closed
        case performance
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("OPEN ORDERS").tag(SimulationTab.open)
                Text("CLOSED ORDERS").tag(SimulationTab.closed)
                Text("PERFORMANCE").tag(SimulationTab.performance)
            }
            .pickerStyle(.segmented)
            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
            .padding(TerminalTheme.paddingMedium)
            .background(TerminalTheme.background)

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .open:
                    OpenOrdersView(
                        simulationManager: simulationManager,
                        orderManager: orderManager,
                        webSocketManager: webSocketManager,
                        selectedAlgorithm: $selectedAlgorithm,
                        productId: productId
                    )
                case .closed:
                    ClosedOrdersView(
                        simulationManager: simulationManager,
                        selectedAlgorithm: $selectedAlgorithm,
                        productId: productId
                    )
                case .performance:
                    PerformanceView(simulationManager: simulationManager, productId: productId)
                }
            }
        }
        .onAppear {
            // Connect simulation manager to algorithm manager if not already connected
            simulationManager.setAlgorithmManager(algorithmManager)
        }
        .onChange(of: webSocketManager?.orderbookSnapshot) { _, newSnapshot in
            // Note: This is handled in SimulationViewWrapper with productId
            // This onChange is kept for compatibility but should not update without productId
        }
    }
}

struct OpenOrdersView: View {
    @ObservedObject var simulationManager: SimulatedOrderManager
    let orderManager: OrderExecutionManager?
    let webSocketManager: WebSocketManager?
    @Binding var selectedAlgorithm: String?
    let productId: String

    private var openOrders: [SimulatedOrder] {
        // CRITICAL: Filter by productId to prevent cross-product contamination
        let orders = simulationManager.getOpenOrders(for: selectedAlgorithm, productId: productId)
        return orders.sorted { $0.createdAt > $1.createdAt }
    }

    private var currentSnapshot: OrderbookSnapshot? {
        webSocketManager?.orderbookSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("OPEN ORDERS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                        .foregroundColor(TerminalTheme.textPrimary)
                    Text("\(openOrders.count) ACTIVE")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                }

                Spacer()

                // Algorithm filter
                Menu {
                    Button("ALL ALGORITHMS") {
                        selectedAlgorithm = nil
                    }
                    ForEach(simulationManager.performanceMetrics.algorithmPerformance.keys.sorted(), id: \.self) { algoId in
                        Button((simulationManager.openOrders.first(where: { $0.algorithmId == algoId })?.algorithmName ?? algoId).uppercased()) {
                            selectedAlgorithm = algoId
                        }
                    }
                } label: {
                    HStack {
                        Text((selectedAlgorithm == nil ? "ALL ALGORITHMS" : (simulationManager.openOrders.first(where: { $0.algorithmId == selectedAlgorithm })?.algorithmName ?? selectedAlgorithm ?? "")).uppercased())
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        Text("▼")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                    }
                    .foregroundColor(TerminalTheme.textPrimary)
                    .padding(.horizontal, TerminalTheme.paddingMedium)
                    .padding(.vertical, TerminalTheme.paddingSmall)
                    .background(TerminalTheme.surface)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.border, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, TerminalTheme.paddingMedium)

            if openOrders.isEmpty {
                VStack(spacing: TerminalTheme.paddingSmall) {
                    Text("📈")
                        .font(.system(size: 30))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("NO OPEN ORDERS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .medium))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("SIMULATED ORDERS WILL APPEAR HERE WHEN ALGORITHMS GENERATE SUGGESTIONS WITH SUFFICIENT LIQUIDITY")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(TerminalTheme.paddingMedium)
            } else {
                ScrollView {
                    LazyVStack(spacing: TerminalTheme.paddingMedium) {
                        ForEach(openOrders) { order in
                            SimulatedOrderCard(
                                order: order,
                                orderManager: orderManager,
                                simulationManager: simulationManager,
                                currentSnapshot: currentSnapshot
                            )
                        }
                    }
                    .padding(.horizontal, TerminalTheme.paddingMedium)
                    .padding(.bottom, TerminalTheme.paddingMedium)
                }
            }
        }
        .background(TerminalTheme.background)
    }
}

struct ClosedOrdersView: View {
    @ObservedObject var simulationManager: SimulatedOrderManager
    @Binding var selectedAlgorithm: String?
    let productId: String

    private var closedOrders: [SimulatedOrder] {
        // CRITICAL: Filter by productId to prevent cross-product contamination
        simulationManager.getClosedOrders(for: selectedAlgorithm, productId: productId, limit: 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("CLOSED ORDERS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                        .foregroundColor(TerminalTheme.textPrimary)
                    Text("\(closedOrders.count) SHOWN")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                }

                Spacer()

                // Algorithm filter
                Menu {
                    Button("ALL ALGORITHMS") {
                        selectedAlgorithm = nil
                    }
                    ForEach(simulationManager.performanceMetrics.algorithmPerformance.keys.sorted(), id: \.self) { algoId in
                        Button((simulationManager.closedOrders.first(where: { $0.algorithmId == algoId })?.algorithmName ?? algoId).uppercased()) {
                            selectedAlgorithm = algoId
                        }
                    }
                } label: {
                    HStack {
                        Text((selectedAlgorithm == nil ? "ALL ALGORITHMS" : (simulationManager.closedOrders.first(where: { $0.algorithmId == selectedAlgorithm })?.algorithmName ?? selectedAlgorithm ?? "")).uppercased())
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        Text("▼")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                    }
                    .foregroundColor(TerminalTheme.textPrimary)
                    .padding(.horizontal, TerminalTheme.paddingMedium)
                    .padding(.vertical, TerminalTheme.paddingSmall)
                    .background(TerminalTheme.surface)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.border, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, TerminalTheme.paddingMedium)

            if closedOrders.isEmpty {
                VStack(spacing: TerminalTheme.paddingSmall) {
                    Text("✓")
                        .font(.system(size: 30))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("NO CLOSED ORDERS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .medium))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(TerminalTheme.paddingMedium)
            } else {
                ScrollView {
                    LazyVStack(spacing: TerminalTheme.paddingSmall) {
                        ForEach(closedOrders) { order in
                            SimulatedOrderCard(
                                order: order,
                                orderManager: nil,
                                simulationManager: simulationManager,
                                currentSnapshot: nil
                            )
                        }
                    }
                    .padding(.horizontal, TerminalTheme.paddingMedium)
                    .padding(.bottom, TerminalTheme.paddingMedium)
                }
            }
        }
        .background(TerminalTheme.background)
    }
}

struct SimulatedOrderCard: View {
    let order: SimulatedOrder
    let orderManager: OrderExecutionManager?
    @ObservedObject var simulationManager: SimulatedOrderManager
    let currentSnapshot: OrderbookSnapshot?
    @State private var isExpanded = false
    @State private var isExecuting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var pnlColor: Color {
        if order.actualPnL > 0 {
            return TerminalTheme.green
        } else if order.actualPnL < 0 {
            return TerminalTheme.red
        } else {
            return TerminalTheme.textSecondary
        }
    }

    private var sideColor: Color {
        order.side == .buy ? TerminalTheme.green : TerminalTheme.red
    }

    private var timeRemaining: String? {
        guard order.status == .open, let targetTime = order.targetCloseTime else {
            return nil
        }
        let remaining = targetTime.timeIntervalSince(Date())
        if remaining <= 0 {
            return "Past target"
        }
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining) % 60
        return "\(minutes)m \(seconds)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text(order.algorithmName.uppercased())
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)

                    HStack(spacing: TerminalTheme.paddingSmall) {
                        // Side badge
                        Text(order.side.rawValue.uppercased())
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background(sideColor)

                        // Status badge
                        Text(order.status == .open ? "OPEN" : "CLOSED")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(order.status == .open ? TerminalTheme.amber : TerminalTheme.textSecondary)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background((order.status == .open ? TerminalTheme.amber : TerminalTheme.textSecondary).opacity(0.15))
                            .overlay(
                                Rectangle()
                                    .stroke(order.status == .open ? TerminalTheme.amber : TerminalTheme.textSecondary, lineWidth: 1)
                            )

                        // Confidence badge
                        Text("\(Int(order.confidence * 100))%")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(TerminalTheme.textSecondary)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background(TerminalTheme.surface)
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.border, lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "−" : "+")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                        .foregroundColor(TerminalTheme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            // Key metrics
            HStack(spacing: TerminalTheme.paddingMedium) {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("ENTRY PRICE")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("$\(order.entryPrice, specifier: "%.2f")")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("CURRENT PRICE")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("$\(order.currentPrice, specifier: "%.2f")")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: TerminalTheme.paddingTiny) {
                    Text("P&L")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("$\(order.actualPnL, specifier: "%.2f")")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(pnlColor)
                }
            }

            // Target info (for open orders)
            if order.status == .open {
                if let targetTime = order.targetCloseTime {
                    HStack {
                        Text("TARGET CLOSE:")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                            .foregroundColor(TerminalTheme.textSecondary)
                        if let remaining = timeRemaining {
                            Text(remaining.uppercased())
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        } else {
                            Text(targetTime, style: .relative)
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                }

                if let goalPnL = order.goalPnL {
                    HStack {
                        Text("GOAL P&L:")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text("$\(goalPnL, specifier: "%.2f")")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(goalPnL >= 0 ? TerminalTheme.green : TerminalTheme.red)
                    }
                }
            } else {
                // Closed order info
                if let exitReason = order.exitReason {
                    HStack {
                        Text("EXIT:")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(exitReason.displayName.uppercased())
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(TerminalTheme.textPrimary)
                    }
                }

                if let closedAt = order.closedAt {
                    HStack {
                        Text("CLOSED:")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(closedAt, style: .relative)
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(TerminalTheme.textPrimary)
                    }
                }
            }

            // Expanded details
            if isExpanded {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

                VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                    Text("DETAILS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                        .foregroundColor(TerminalTheme.textSecondary)

                    Text(order.reasoning.uppercased())
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)

                    HStack {
                        Text("SIZE:")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text("\(order.size, specifier: "%.4f")")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                            .foregroundColor(TerminalTheme.textPrimary)
                    }

                    if let targetPrice = order.targetPrice {
                        HStack {
                            Text("TARGET PRICE:")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }

                    Text("PRODUCT: \(order.productId)")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
            }

            // Action buttons
            if order.status == .open {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

                HStack(spacing: TerminalTheme.paddingSmall) {
                    // Close manually button
                    Button(action: {
                        if let snapshot = currentSnapshot {
                            simulationManager.closeOrderManually(orderId: order.id, snapshot: snapshot)
                        }
                    }) {
                        Text("CLOSE NOW")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TerminalTheme.paddingSmall)
                            .background(TerminalTheme.amber)
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.border, lineWidth: 1)
                            )
                    }

                    // Execute real order button
                    if let orderManager = orderManager {
                        Button(action: {
                            executeRealOrder()
                        }) {
                            HStack(spacing: TerminalTheme.paddingTiny) {
                                if isExecuting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.black)
                                } else {
                                    Text("↑")
                                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                                }
                                Text(isExecuting ? "EXECUTING..." : "EXECUTE REAL")
                                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TerminalTheme.paddingSmall)
                            .background(sideColor)
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.border, lineWidth: 1)
                            )
                        }
                        .disabled(isExecuting)
                    }
                }
            }
        }
        .padding(TerminalTheme.paddingMedium)
        .background(TerminalTheme.surface)
        .overlay(
            Rectangle()
                .stroke(sideColor.opacity(0.5), lineWidth: 1)
        )
        .alert("ORDER ERROR", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func executeRealOrder() {
        guard let orderManager = orderManager else { return }

        let suggestion = OrderSuggestion(
            algorithmName: order.algorithmName,
            algorithmId: order.algorithmId,
            side: order.side,
            productId: order.productId,
            suggestedPrice: order.currentPrice,
            suggestedSize: order.size,
            confidence: order.confidence,
            reasoning: order.reasoning,
            targetCloseTime: order.targetCloseTime,
            goalPnL: order.goalPnL,
            targetPrice: order.targetPrice
        )

        Task {
            isExecuting = true
            do {
                _ = try await orderManager.executeSuggestion(suggestion)
                // Success - order was created
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isExecuting = false
        }
    }
}
