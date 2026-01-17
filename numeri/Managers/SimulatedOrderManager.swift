//
//  SimulatedOrderManager.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Combine
import Foundation

/// Manages simulated order execution, tracking, and performance metrics
class SimulatedOrderManager: ObservableObject {
    @Published private(set) var openOrders: [SimulatedOrder] = []
    @Published private(set) var closedOrders: [SimulatedOrder] = []
    @Published private(set) var performanceMetrics: PerformanceMetrics = .init()

    private var cancellables = Set<AnyCancellable>()
    private let persistenceQueue = DispatchQueue(label: "com.numeri.simulation.persistence", qos: .utility)
    private var latestSnapshot: OrderbookSnapshot?
    private var currentProductId: String = ""

    private let persistenceKey = "com.numeri.simulatedOrders"
    private let metricsKey = "com.numeri.performanceMetrics"

    var algorithmManager: AlgorithmMetricsManager?
    var feeService: FeeService?

    init(algorithmManager: AlgorithmMetricsManager? = nil) {
        self.algorithmManager = algorithmManager
        loadPersistedData()

        // Subscribe to new suggestions from algorithm manager
        if let algorithmManager = algorithmManager {
            algorithmManager.$newSuggestions
                .sink { [weak self] newSuggestions in
                    guard let self = self, let snapshot = self.latestSnapshot else { return }
                    for suggestion in newSuggestions {
                        // Only create orders for the current product
                        if suggestion.productId == self.currentProductId {
                            _ = self.createSimulatedOrder(from: suggestion, snapshot: snapshot)
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        // Listen for clear data notification
        NotificationCenter.default.publisher(for: NSNotification.Name("ClearSimulationData"))
            .sink { [weak self] _ in
                self?.clearAllData()
            }
            .store(in: &cancellables)
    }

    func setAlgorithmManager(_ manager: AlgorithmMetricsManager) {
        algorithmManager = manager
        manager.$newSuggestions
            .sink { [weak self] newSuggestions in
                guard let self = self, let snapshot = self.latestSnapshot else { return }
                for suggestion in newSuggestions {
                    // Only create orders for the current product
                    if suggestion.productId == self.currentProductId {
                        _ = self.createSimulatedOrder(from: suggestion, snapshot: snapshot)
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Set the latest orderbook snapshot for price tracking and processing new suggestions
    func updateSnapshot(_ snapshot: OrderbookSnapshot, productId: String) {
        latestSnapshot = snapshot
        currentProductId = productId
        updateWithSnapshot(snapshot, productId: productId)
    }

    // MARK: - Order Creation

    /// Create a simulated order from a suggestion if liquidity is available
    func createSimulatedOrder(from suggestion: OrderSuggestion, snapshot: OrderbookSnapshot) -> Bool {
        // Check liquidity at the suggested price
        guard checkLiquidity(price: suggestion.suggestedPrice, size: suggestion.suggestedSize, side: suggestion.side, snapshot: snapshot) else {
            return false
        }

        let order = SimulatedOrder(
            id: UUID().uuidString,
            algorithmId: suggestion.algorithmId,
            algorithmName: suggestion.algorithmName,
            productId: suggestion.productId,
            side: suggestion.side,
            entryPrice: suggestion.suggestedPrice,
            size: suggestion.suggestedSize,
            confidence: suggestion.confidence,
            reasoning: suggestion.reasoning,
            targetCloseTime: suggestion.targetCloseTime,
            targetPrice: suggestion.targetPrice,
            goalPnL: suggestion.goalPnL,
            createdAt: Date(),
            currentPrice: suggestion.suggestedPrice,
            actualPnL: 0.0,
            status: .open
        )

        DispatchQueue.main.async {
            self.openOrders.append(order)
            self.persistData()
        }

        return true
    }

    // MARK: - Liquidity Checking

    /// Check if there's enough liquidity at the specified price level
    /// For BUY orders: Only allows maker orders (post_only) - price must be at or below best bid
    /// For SELL orders: Allows both maker and taker orders
    private func checkLiquidity(price: Double, size: Double, side: OrderSide, snapshot: OrderbookSnapshot) -> Bool {
        if side == .buy {
            // BUY orders must be maker orders (post_only)
            // For a maker BUY order, the price must be at or below the best bid
            // This ensures the order sits on the orderbook and doesn't immediately match
            guard let bestBid = snapshot.bids.first else {
                return false
            }
            
            // Price must be <= best bid to be a maker order
            // If price > best bid, it would immediately match (taker order), which we don't allow for BUY
            guard price <= bestBid.price else {
                return false
            }
            
            // For a maker order, we don't need immediate matching liquidity since it sits on the book
            // But we should ensure there's reasonable market depth for when we want to exit
            // Check that there's sufficient ask liquidity for potential exit
            let totalAskLiquidity = snapshot.offers
                .prefix(5) // Check top 5 levels
                .reduce(0.0) { $0 + $1.quantity }
            
            // Require at least some market depth (30% of order size) for exit liquidity
            return totalAskLiquidity >= size * 0.3
        } else {
            // SELL orders can be maker or taker
            // Check if there's liquidity to match against (bids at or above our price)
            let relevantEntries = snapshot.bids
            
            // Find the entry at or better than the target price
            // For sell orders, we need bids at or above the price (to match against)
            let matchingEntry = relevantEntries.first { $0.price >= price }
            
            guard let entry = matchingEntry else {
                return false
            }
            
            // Check if there's enough quantity at this price level
            return entry.quantity >= size
        }
    }

    // MARK: - Price Tracking

    /// Start tracking price for an open order
    private func startPriceTracking(for _: SimulatedOrder, snapshot _: OrderbookSnapshot) {
        // Price tracking is now handled via updateSnapshot calls
        // No need for timers since we'll update on each snapshot
    }

    /// Update order price and check for exit conditions
    private func updateOrderPrice(orderId: String, snapshot: OrderbookSnapshot) {
        guard let index = openOrders.firstIndex(where: { $0.id == orderId }) else {
            return
        }

        let order = openOrders[index]
        guard let currentPrice = snapshot.midPrice else { return }

        // CRITICAL: Double-check that this order belongs to the product we're updating
        // This is a safety check to prevent cross-product price updates
        guard order.productId == currentProductId else {
            print("⚠️ Warning: Attempted to update order \(orderId) for product \(order.productId) with snapshot for product \(currentProductId). Skipping.")
            return
        }

        // Only update if order is still open
        guard order.status == .open else { return }

        // Calculate current PnL
        let currentPnL = calculatePnL(
            entryPrice: order.entryPrice,
            currentPrice: currentPrice,
            size: order.size,
            side: order.side
        )

        // Update order with current price and PnL
        let updatedOrder = SimulatedOrder(
            id: order.id,
            algorithmId: order.algorithmId,
            algorithmName: order.algorithmName,
            productId: order.productId,
            side: order.side,
            entryPrice: order.entryPrice,
            size: order.size,
            confidence: order.confidence,
            reasoning: order.reasoning,
            targetCloseTime: order.targetCloseTime,
            targetPrice: order.targetPrice,
            goalPnL: order.goalPnL,
            createdAt: order.createdAt,
            currentPrice: currentPrice,
            actualPnL: currentPnL,
            status: order.status,
            closedAt: order.closedAt,
            exitPrice: order.exitPrice,
            exitReason: order.exitReason
        )

        openOrders[index] = updatedOrder

        // Check if we should close the order
        checkExitConditions(for: updatedOrder, snapshot: snapshot)
    }

    /// Check if order should be closed (target time reached or early exit conditions)
    private func checkExitConditions(for order: SimulatedOrder, snapshot: OrderbookSnapshot) {
        guard order.status == .open else { return }

        let now = Date()
        var shouldClose = false
        var exitReason: ExitReason = .targetTimeReached

        // Check if target close time has been reached
        if let targetTime = order.targetCloseTime, now >= targetTime {
            shouldClose = true
            exitReason = .targetTimeReached
        }

        // Check if we can exit early (target price reached with liquidity)
        if let targetPrice = order.targetPrice, let currentPrice = snapshot.midPrice {
            let priceReached = (order.side == .buy && currentPrice >= targetPrice) ||
                (order.side == .sell && currentPrice <= targetPrice)

            if priceReached {
                // Check liquidity at target price for exit
                if checkLiquidity(price: targetPrice, size: order.size, side: order.side == .buy ? .sell : .buy, snapshot: snapshot) {
                    shouldClose = true
                    exitReason = .targetPriceReached
                }
            }
        }

        if shouldClose {
            closeOrder(orderId: order.id, exitPrice: snapshot.midPrice, exitReason: exitReason)
        }
    }

    // MARK: - Order Closing

    /// Close an order at the current price
    func closeOrder(orderId: String, exitPrice: Double?, exitReason: ExitReason) {
        guard let index = openOrders.firstIndex(where: { $0.id == orderId }) else {
            return
        }

        let order = openOrders[index]
        let finalPrice = exitPrice ?? order.currentPrice
        let finalPnL = calculatePnL(
            entryPrice: order.entryPrice,
            currentPrice: finalPrice,
            size: order.size,
            side: order.side
        )

        let closedOrder = SimulatedOrder(
            id: order.id,
            algorithmId: order.algorithmId,
            algorithmName: order.algorithmName,
            productId: order.productId,
            side: order.side,
            entryPrice: order.entryPrice,
            size: order.size,
            confidence: order.confidence,
            reasoning: order.reasoning,
            targetCloseTime: order.targetCloseTime,
            targetPrice: order.targetPrice,
            goalPnL: order.goalPnL,
            createdAt: order.createdAt,
            currentPrice: finalPrice,
            actualPnL: finalPnL,
            status: .filled,
            closedAt: Date(),
            exitPrice: finalPrice,
            exitReason: exitReason
        )

        openOrders.remove(at: index)
        closedOrders.insert(closedOrder, at: 0)

        // Update performance metrics
        updatePerformanceMetrics(with: closedOrder)

        // Persist data
        persistData()
    }

    /// Manually close an order
    func closeOrderManually(orderId: String, snapshot: OrderbookSnapshot) {
        guard let currentPrice = snapshot.midPrice else { return }
        closeOrder(orderId: orderId, exitPrice: currentPrice, exitReason: .manual)
    }

    // MARK: - PnL Calculation

    private func calculatePnL(entryPrice: Double, currentPrice: Double, size: Double, side: OrderSide) -> Double {
        let grossPnL: Double
        if side == .buy {
            // Profit = (exit price - entry price) * size
            grossPnL = (currentPrice - entryPrice) * size
        } else {
            // Profit = (entry price - exit price) * size
            grossPnL = (entryPrice - currentPrice) * size
        }
        
        // Subtract fees from gross PnL
        let fees = calculateFees(entryPrice: entryPrice, exitPrice: currentPrice, size: size, side: side)
        return grossPnL - fees
    }
    
    /// Calculate fees for a trade (entry + exit)
    private func calculateFees(entryPrice: Double, exitPrice: Double, size: Double, side: OrderSide) -> Double {
        guard let feeService = feeService,
              let feeTier = feeService.transactionSummary?.feeTier else {
            // If no fee data available, return 0 (no fees deducted)
            return 0.0
        }
        
        // Use taker fee rate (assuming market orders)
        // In a real scenario, you might want to use maker fee if it's a limit order
        let feeRate = feeTier.takerFeeRateDouble
        
        // Calculate notional values
        let entryNotional = entryPrice * size
        let exitNotional = exitPrice * size
        
        // Fees are charged on both entry and exit
        let entryFee = entryNotional * feeRate
        let exitFee = exitNotional * feeRate
        
        return entryFee + exitFee
    }

    // MARK: - Performance Metrics

    private func updatePerformanceMetrics(with order: SimulatedOrder) {
        guard order.status == .filled else { return }

        var metrics = performanceMetrics

        metrics.totalOrders += 1
        metrics.totalPnL += order.actualPnL

        if order.actualPnL > 0 {
            metrics.winningTrades += 1
        } else if order.actualPnL < 0 {
            metrics.losingTrades += 1
        }

        // Track by algorithm
        if metrics.algorithmPerformance[order.algorithmId] == nil {
            metrics.algorithmPerformance[order.algorithmId] = AlgorithmPerformance()
        }

        var algoPerf = metrics.algorithmPerformance[order.algorithmId]!
        algoPerf.totalOrders += 1
        algoPerf.totalPnL += order.actualPnL
        if order.actualPnL > 0 {
            algoPerf.winningTrades += 1
        } else if order.actualPnL < 0 {
            algoPerf.losingTrades += 1
        }
        metrics.algorithmPerformance[order.algorithmId] = algoPerf

        // Add to historical data
        let dataPoint = PerformanceDataPoint(
            date: order.closedAt ?? Date(),
            pnl: order.actualPnL,
            algorithmId: order.algorithmId
        )
        metrics.historicalData.append(dataPoint)

        // Keep only last 1000 data points
        if metrics.historicalData.count > 1000 {
            metrics.historicalData = Array(metrics.historicalData.suffix(1000))
        }

        performanceMetrics = metrics
        persistMetrics()
    }

    // MARK: - Price Tracking Management

    /// Update all open orders with new snapshot - ONLY for the specified product
    private func updateWithSnapshot(_ snapshot: OrderbookSnapshot, productId: String) {
        // CRITICAL: Only update orders that match the current productId
        // This prevents mixing prices from different products
        for order in openOrders where order.productId == productId {
            updateOrderPrice(orderId: order.id, snapshot: snapshot)
        }
    }

    // MARK: - Data Persistence

    private func persistData() {
        persistenceQueue.async { [weak self] in
            guard let self = self else { return }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            do {
                let openData = try encoder.encode(self.openOrders)
                let closedData = try encoder.encode(self.closedOrders)

                UserDefaults.standard.set(openData, forKey: "\(self.persistenceKey).open")
                UserDefaults.standard.set(closedData, forKey: "\(self.persistenceKey).closed")
            } catch {
                print("Failed to persist simulated orders: \(error)")
            }
        }
    }

    private func persistMetrics() {
        let metrics = performanceMetrics
        Task { @MainActor in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            do {
                let data = try encoder.encode(metrics)
                persistenceQueue.async { [weak self] in
                    guard let self = self else { return }
                    UserDefaults.standard.set(data, forKey: self.metricsKey)
                }
            } catch {
                print("Failed to persist performance metrics: \(error)")
            }
        }
    }

    private func loadPersistedData() {
        persistenceQueue.async { [weak self] in
            guard let self = self else { return }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let openData = UserDefaults.standard.data(forKey: "\(self.persistenceKey).open"),
               let open = try? decoder.decode([SimulatedOrder].self, from: openData)
            {
                DispatchQueue.main.async {
                    self.openOrders = open
                }
            }

            if let closedData = UserDefaults.standard.data(forKey: "\(self.persistenceKey).closed"),
               let closed = try? decoder.decode([SimulatedOrder].self, from: closedData)
            {
                DispatchQueue.main.async {
                    self.closedOrders = closed
                }
            }

            if let metricsData = UserDefaults.standard.data(forKey: self.metricsKey) {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let metrics = try? decoder.decode(PerformanceMetrics.self, from: metricsData) {
                        self.performanceMetrics = metrics
                    }
                }
            }
        }
    }

    // MARK: - Query Methods

    func getOpenOrders(for algorithmId: String? = nil, productId: String? = nil) -> [SimulatedOrder] {
        var orders = openOrders
        
        // CRITICAL: Filter by productId first to prevent cross-product contamination
        if let productId = productId {
            orders = orders.filter { $0.productId == productId }
        }
        
        if let algorithmId = algorithmId {
            orders = orders.filter { $0.algorithmId == algorithmId }
        }
        return orders
    }

    func getClosedOrders(for algorithmId: String? = nil, productId: String? = nil, limit: Int = 100) -> [SimulatedOrder] {
        var orders = closedOrders
        
        // CRITICAL: Filter by productId first to prevent cross-product contamination
        if let productId = productId {
            orders = orders.filter { $0.productId == productId }
        }
        
        if let algorithmId = algorithmId {
            orders = orders.filter { $0.algorithmId == algorithmId }
        }
        return Array(orders.prefix(limit))
    }
    
    func getPerformanceMetrics(for algorithmId: String? = nil, productId: String? = nil) -> PerformanceMetrics {
        // Filter metrics by productId if specified
        if let productId = productId {
            var filtered = PerformanceMetrics()
            
            // Filter closed orders by productId
            let productOrders = closedOrders.filter { $0.productId == productId }
            
            filtered.totalOrders = productOrders.count
            filtered.winningTrades = productOrders.filter { $0.actualPnL > 0 }.count
            filtered.losingTrades = productOrders.filter { $0.actualPnL < 0 }.count
            filtered.totalPnL = productOrders.reduce(0) { $0 + $1.actualPnL }
            
            // Filter algorithm performance by productId
            var algoPerf: [String: AlgorithmPerformance] = [:]
            for order in productOrders {
                if algoPerf[order.algorithmId] == nil {
                    algoPerf[order.algorithmId] = AlgorithmPerformance()
                }
                var perf = algoPerf[order.algorithmId]!
                perf.totalOrders += 1
                perf.totalPnL += order.actualPnL
                if order.actualPnL > 0 {
                    perf.winningTrades += 1
                } else if order.actualPnL < 0 {
                    perf.losingTrades += 1
                }
                algoPerf[order.algorithmId] = perf
            }
            filtered.algorithmPerformance = algoPerf
            
            // Rebuild historical data from filtered orders (since PerformanceDataPoint doesn't store productId)
            // This ensures we only show data for the current product
            filtered.historicalData = productOrders.map { order in
                PerformanceDataPoint(
                    date: order.closedAt ?? order.createdAt,
                    pnl: order.actualPnL,
                    algorithmId: order.algorithmId
                )
            }.sorted { $0.date < $1.date }
            
            // Further filter by algorithmId if specified
            if let algorithmId = algorithmId {
                filtered.algorithmPerformance = [algorithmId: filtered.algorithmPerformance[algorithmId] ?? AlgorithmPerformance()]
            }
            
            return filtered
        }
        
        // Original logic for algorithmId filtering only
        if let algorithmId = algorithmId {
            var filtered = performanceMetrics
            filtered.algorithmPerformance = [algorithmId: performanceMetrics.algorithmPerformance[algorithmId] ?? AlgorithmPerformance()]
            return filtered
        }
        return performanceMetrics
    }

    func getPerformanceMetrics(for algorithmId: String? = nil) -> PerformanceMetrics {
        if let algorithmId = algorithmId {
            var filtered = performanceMetrics
            filtered.algorithmPerformance = [algorithmId: performanceMetrics.algorithmPerformance[algorithmId] ?? AlgorithmPerformance()]
            return filtered
        }
        return performanceMetrics
    }
    
    // MARK: - Data Management
    
    /// Clear all performance data and reset to initial state
    func clearAllData() {
        DispatchQueue.main.async {
            self.openOrders.removeAll()
            self.closedOrders.removeAll()
            self.performanceMetrics = PerformanceMetrics()
            self.persistData()
            self.persistMetrics()
        }
    }
    
    /// Static method to clear persisted data from UserDefaults
    static func clearPersistedData() {
        let persistenceKey = "com.numeri.simulatedOrders"
        let metricsKey = "com.numeri.performanceMetrics"
        
        UserDefaults.standard.removeObject(forKey: "\(persistenceKey).open")
        UserDefaults.standard.removeObject(forKey: "\(persistenceKey).closed")
        UserDefaults.standard.removeObject(forKey: metricsKey)
    }
}
