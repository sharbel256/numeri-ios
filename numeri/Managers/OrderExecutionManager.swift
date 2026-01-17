//
//  OrderExecutionManager.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Combine
import Foundation

/// Manages order execution, tracking, and status updates
class OrderExecutionManager: ObservableObject {
    @Published private(set) var orders: [String: Order] = [:]
    @Published private(set) var ordersByProduct: [String: [Order]] = [:]
    @Published private(set) var recentOrders: [Order] = []
    @Published private(set) var isExecuting = false
    @Published private(set) var lastError: String?

    private var accessToken: String?
    private let baseURL = "https://api.coinbase.com/api/v3/brokerage"
    private let pollingQueue = DispatchQueue(label: "com.numeri.orders.polling", qos: .utility)
    private var pollingTimers: [String: Timer] = [:]
    private var pollingPermissionErrors: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshHandler: (() async -> String?)?

    private let maxRecentOrders = 100
    private let pollingInterval: TimeInterval = 2.0
    private let maxPollingDuration: TimeInterval = 300

    init(accessToken: String?, tokenRefreshHandler: (() async -> String?)? = nil) {
        self.accessToken = accessToken
        self.tokenRefreshHandler = tokenRefreshHandler
    }

    func updateToken(_ newToken: String?) {
        accessToken = newToken
    }

    func setTokenRefreshHandler(_ handler: @escaping () async -> String?) {
        tokenRefreshHandler = handler
    }

    func invalidateToken() {
        accessToken = nil
        for timer in pollingTimers.values {
            timer.invalidate()
        }
        pollingTimers.removeAll()
    }

    private func refreshTokenIfNeeded() async -> Bool {
        guard let handler = tokenRefreshHandler else {
            return false
        }

        if let newToken = await handler() {
            accessToken = newToken
            return true
        }
        return false
    }

    /// Makes an API request with automatic token refresh on 401/403 errors
    private func makeAPIRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        shouldRetry: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        guard let token = accessToken else {
            throw OrderError.apiError("Authentication required. Please log in.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderError.invalidResponse
        }

        // If we get 401 or 403, try refreshing the token and retry once
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403, shouldRetry {
            print("Access token expired (status \(httpResponse.statusCode)), attempting to refresh...")
            let refreshSuccess = await refreshTokenIfNeeded()

            if refreshSuccess {
                print("Token refreshed successfully, retrying API request...")
                // Retry the request with the new token
                return try await makeAPIRequest(url: url, method: method, body: body, shouldRetry: false)
            } else {
                throw OrderError.apiError("Failed to refresh token. Please log in again.")
            }
        }

        return (data, httpResponse)
    }

    // MARK: - Missed Opportunities

    /// Record a missed opportunity (suggestion that wasn't executed)
    func recordMissedOpportunity(_ suggestion: OrderSuggestion) {
        let missedOrder = Order(
            id: UUID().uuidString,
            clientOrderId: nil,
            productId: suggestion.productId,
            side: suggestion.side,
            orderType: .limit,
            status: .rejected,
            price: suggestion.suggestedPrice,
            size: suggestion.suggestedSize,
            filledSize: 0.0,
            averageFilledPrice: nil,
            createdAt: suggestion.timestamp,
            updatedAt: Date(),
            source: .missed,
            stopPrice: nil,
            timeInForce: nil,
            postOnly: nil,
            rejectReason: "Not executed by user",
            algorithmId: suggestion.algorithmId,
            algorithmName: suggestion.algorithmName,
            targetCloseTime: suggestion.targetCloseTime,
            goalPnL: suggestion.goalPnL,
            actualPnL: nil,
            targetPrice: suggestion.targetPrice,
            totalFees: nil,
            filledValue: nil,
            totalValueAfterFees: nil,
            numberOfFills: nil,
            lastFillTime: nil
        )

        DispatchQueue.main.async {
            self.addOrder(missedOrder)
        }
    }

    /// Update actual PnL for missed opportunities when target close time is reached
    func updateMissedOpportunityPnL(orderId: String, currentPrice: Double) {
        guard let order = orders[orderId],
              order.source == .missed,
              let entryPrice = order.price,
              let size = order.size
        else {
            return
        }

        let actualPnL: Double
        if order.side == .buy {
            actualPnL = (currentPrice - entryPrice) * size
        } else {
            actualPnL = (entryPrice - currentPrice) * size
        }

        let updatedOrder = Order(
            id: order.id,
            clientOrderId: order.clientOrderId,
            productId: order.productId,
            side: order.side,
            orderType: order.orderType,
            status: order.status,
            price: order.price,
            size: order.size,
            filledSize: order.filledSize,
            averageFilledPrice: order.averageFilledPrice,
            createdAt: order.createdAt,
            updatedAt: Date(),
            source: order.source,
            stopPrice: order.stopPrice,
            timeInForce: order.timeInForce,
            postOnly: order.postOnly,
            rejectReason: order.rejectReason,
            algorithmId: order.algorithmId,
            algorithmName: order.algorithmName,
            targetCloseTime: order.targetCloseTime,
            goalPnL: order.goalPnL,
            actualPnL: actualPnL,
            targetPrice: order.targetPrice,
            totalFees: order.totalFees,
            filledValue: order.filledValue,
            totalValueAfterFees: order.totalValueAfterFees,
            numberOfFills: order.numberOfFills,
            lastFillTime: order.lastFillTime
        )

        DispatchQueue.main.async {
            self.addOrder(updatedOrder)
        }
    }

    // MARK: - Order Execution

    /// Execute an order from a suggestion
    /// BUY orders are always maker orders (post_only = true)
    /// SELL orders can be maker or taker (post_only = nil, allowing either)
    func executeSuggestion(_ suggestion: OrderSuggestion, orderType: OrderType = .limit) async throws -> Order {
        // BUY orders must be maker orders (post_only)
        let postOnly = suggestion.side == .buy ? true : nil
        
        let request = CreateOrderRequest(
            productId: suggestion.productId,
            side: suggestion.side,
            orderType: orderType,
            price: orderType == .limit ? suggestion.suggestedPrice : nil,
            size: suggestion.suggestedSize,
            postOnly: postOnly,
            clientOrderId: UUID().uuidString
        )

        return try await executeOrder(request: request, source: .suggestion, algorithmId: suggestion.algorithmId, algorithmName: suggestion.algorithmName)
    }

    /// Execute a manual order
    func executeOrder(
        productId: String,
        side: OrderSide,
        orderType: OrderType,
        price: Double? = nil,
        size: Double? = nil,
        stopPrice: Double? = nil,
        timeInForce: TimeInForce? = nil,
        postOnly: Bool? = nil
    ) async throws -> Order {
        let request = CreateOrderRequest(
            productId: productId,
            side: side,
            orderType: orderType,
            price: price,
            size: size,
            stopPrice: stopPrice,
            timeInForce: timeInForce,
            postOnly: postOnly,
            clientOrderId: UUID().uuidString
        )

        return try await executeOrder(request: request, source: .manual)
    }

    private func executeOrder(
        request: CreateOrderRequest,
        source: OrderSource,
        algorithmId: String? = nil,
        algorithmName: String? = nil
    ) async throws -> Order {
        guard let token = accessToken else {
            throw OrderError.apiError("Authentication required. Please log in.")
        }

        DispatchQueue.main.async {
            self.isExecuting = true
            self.lastError = nil
        }

        defer {
            DispatchQueue.main.async {
                self.isExecuting = false
            }
        }

        guard let url = URL(string: "\(baseURL)/orders") else {
            throw OrderError.invalidURL
        }

        let jsonData = try JSONSerialization.data(withJSONObject: request.toCoinbaseJSON())

        let (data, httpResponse) = try await makeAPIRequest(
            url: url,
            method: "POST",
            body: jsonData
        )

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let errorMessage = errorData.message ?? errorData.error
                DispatchQueue.main.async {
                    self.lastError = errorMessage
                }
                throw OrderError.apiError(errorMessage)
            }
            throw OrderError.httpError(httpResponse.statusCode)
        }

        let orderResponse = try JSONDecoder().decode(CreateOrderResponse.self, from: data)

        guard orderResponse.success, let orderId = orderResponse.orderId ?? orderResponse.successResponse?.orderId else {
            let errorMessage = orderResponse.failureReason ?? "Unknown error"
            DispatchQueue.main.async {
                self.lastError = errorMessage
            }
            throw OrderError.apiError(errorMessage)
        }

        let fullOrder: Order
        var hasPermissionError = false

        do {
            let order = try await fetchOrder(orderId: orderId)
            fullOrder = Order(
                id: order.id,
                clientOrderId: order.clientOrderId ?? request.clientOrderId,
                productId: order.productId,
                side: order.side,
                orderType: order.orderType,
                status: order.status,
                price: order.price,
                size: order.size,
                filledSize: order.filledSize,
                averageFilledPrice: order.averageFilledPrice,
                createdAt: order.createdAt,
                updatedAt: order.updatedAt,
                source: source,
                stopPrice: order.stopPrice,
                timeInForce: order.timeInForce,
                postOnly: order.postOnly,
                rejectReason: order.rejectReason,
                algorithmId: algorithmId,
                algorithmName: algorithmName,
                targetCloseTime: nil,
                goalPnL: nil,
                actualPnL: nil,
                targetPrice: nil,
                totalFees: order.totalFees,
                filledValue: order.filledValue,
                totalValueAfterFees: order.totalValueAfterFees,
                numberOfFills: order.numberOfFills,
                lastFillTime: order.lastFillTime
            )
        } catch {
            if case let OrderError.httpError(statusCode) = error, statusCode == 403 {
                hasPermissionError = true
            }

            let successResponse = orderResponse.successResponse
            let now = Date()

            let orderSide: OrderSide
            if let sideString = successResponse?.side, let side = OrderSide(rawValue: sideString.uppercased()) {
                orderSide = side
            } else {
                orderSide = request.side
            }

            fullOrder = Order(
                id: orderId,
                clientOrderId: successResponse?.clientOrderId ?? request.clientOrderId,
                productId: successResponse?.productId ?? request.productId,
                side: orderSide,
                orderType: request.orderType,
                status: .pending,
                price: request.price,
                size: request.size,
                filledSize: 0.0,
                averageFilledPrice: nil,
                createdAt: now,
                updatedAt: now,
                source: source,
                stopPrice: request.stopPrice,
                timeInForce: request.timeInForce,
                postOnly: request.postOnly,
                rejectReason: nil,
                algorithmId: algorithmId,
                algorithmName: algorithmName,
                targetCloseTime: nil,
                goalPnL: nil,
                actualPnL: nil,
                targetPrice: nil,
                totalFees: nil,
                filledValue: nil,
                totalValueAfterFees: nil,
                numberOfFills: nil,
                lastFillTime: nil
            )
        }

        DispatchQueue.main.async {
            self.addOrder(fullOrder)
            if hasPermissionError {
                self.pollingPermissionErrors.insert(orderId)
            } else {
                self.startPolling(orderId: orderId)
            }
        }

        return fullOrder
    }

    // MARK: - Order Fetching

    func fetchOrder(orderId: String) async throws -> Order {
        guard let url = URL(string: "\(baseURL)/orders/historical/\(orderId)") else {
            throw OrderError.invalidURL
        }

        let (data, httpResponse) = try await makeAPIRequest(url: url)

        if httpResponse.statusCode != 200 {
            throw OrderError.httpError(httpResponse.statusCode)
        }

        struct OrderWrapper: Codable {
            let order: CoinbaseOrder
        }

        let wrapper = try JSONDecoder().decode(OrderWrapper.self, from: data)
        return try convertCoinbaseOrder(wrapper.order)
    }

    @Published private(set) var canFetchOrders = true

    func fetchOrders(productId: String? = nil, limit: Int = 50, startDate: Date? = nil) async throws {
        // Default to last 48 hours if no start date provided
        let defaultStartDate = startDate ?? Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startDateString = formatter.string(from: defaultStartDate)

        // Build query string manually to ensure proper formatting of array parameters
        var queryParams: [String] = [
            "start_date=\(startDateString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? startDateString)",
            "limit=\(limit)",
        ]

        // Note: Not filtering by order_status - let API return all statuses
        // The API may not properly handle multiple order_status parameters
        // We'll filter client-side in getOpenOrders(), getFilledOrders(), etc.

        if let productId = productId {
            queryParams.append("product_id=\(productId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productId)")
        }

        let queryString = queryParams.joined(separator: "&")
        guard let url = URL(string: "\(baseURL)/orders/historical/batch?\(queryString)") else {
            throw OrderError.invalidURL
        }

        let (data, httpResponse) = try await makeAPIRequest(url: url)

        if httpResponse.statusCode == 403 {
            DispatchQueue.main.async {
                self.canFetchOrders = false
            }
            return
        }

        if httpResponse.statusCode != 200 {
            throw OrderError.httpError(httpResponse.statusCode)
        }

        struct OrdersWrapper: Codable {
            let orders: [CoinbaseOrder]
            let hasNext: Bool?

            enum CodingKeys: String, CodingKey {
                case orders
                case hasNext = "has_next"
            }
        }

        let wrapper = try JSONDecoder().decode(OrdersWrapper.self, from: data)

        DispatchQueue.main.async {
            self.canFetchOrders = true
            for coinbaseOrder in wrapper.orders {
                do {
                    let order = try self.convertCoinbaseOrder(coinbaseOrder)
                    self.addOrder(order)
                } catch {
                    // Log conversion failures with detailed error information
                    print("Failed to convert order \(coinbaseOrder.orderId): \(error.localizedDescription)")
                    print("  Status: \(coinbaseOrder.status)")
                    print("  Side: \(coinbaseOrder.side)")
                    if let config = coinbaseOrder.orderConfiguration {
                        print("  Config keys: \(config)")
                    }
                }
            }
        }
    }

    // MARK: - Order Cancellation

    func cancelOrder(orderId: String) async throws {
        do {
            try await cancelOrderSingle(orderId: orderId)
            return
        } catch {
            try await cancelOrdersBatch(orderIds: [orderId])
        }
    }

    private func cancelOrderSingle(orderId: String) async throws {
        guard let url = URL(string: "\(baseURL)/orders/\(orderId)") else {
            throw OrderError.invalidURL
        }

        let (_, httpResponse) = try await makeAPIRequest(url: url, method: "DELETE")

        if httpResponse.statusCode != 200, httpResponse.statusCode != 204 {
            throw OrderError.httpError(httpResponse.statusCode)
        }

        // Update order status locally
        DispatchQueue.main.async {
            if let order = self.orders[orderId] {
                let updatedOrder = Order(
                    id: order.id,
                    clientOrderId: order.clientOrderId,
                    productId: order.productId,
                    side: order.side,
                    orderType: order.orderType,
                    status: .canceled,
                    price: order.price,
                    size: order.size,
                    filledSize: order.filledSize,
                    averageFilledPrice: order.averageFilledPrice,
                    createdAt: order.createdAt,
                    updatedAt: Date(),
                    source: order.source,
                    stopPrice: order.stopPrice,
                    timeInForce: order.timeInForce,
                    postOnly: order.postOnly,
                    rejectReason: order.rejectReason,
                    algorithmId: order.algorithmId,
                    algorithmName: order.algorithmName,
                    targetCloseTime: order.targetCloseTime,
                    goalPnL: order.goalPnL,
                    actualPnL: order.actualPnL,
                    targetPrice: order.targetPrice,
                    totalFees: order.totalFees,
                    filledValue: order.filledValue,
                    totalValueAfterFees: order.totalValueAfterFees,
                    numberOfFills: order.numberOfFills,
                    lastFillTime: order.lastFillTime
                )
                self.addOrder(updatedOrder)
                self.stopPolling(orderId: orderId)
            }
        }
    }

    /// Cancel multiple orders using batch_cancel endpoint
    func cancelOrders(orderIds: [String]) async throws {
        try await cancelOrdersBatch(orderIds: orderIds)
    }

    private func cancelOrdersBatch(orderIds: [String]) async throws {
        guard let url = URL(string: "\(baseURL)/orders/batch_cancel") else {
            throw OrderError.invalidURL
        }

        let requestBody: [String: Any] = ["order_ids": orderIds]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await makeAPIRequest(
            url: url,
            method: "POST",
            body: jsonData
        )

        if httpResponse.statusCode != 200 {
            throw OrderError.httpError(httpResponse.statusCode)
        }

        struct BatchCancelResponse: Codable {
            let results: [CancelResult]
        }

        struct CancelResult: Codable {
            let success: Bool
            let failureReason: String?
            let orderId: String?

            enum CodingKeys: String, CodingKey {
                case success
                case failureReason = "failure_reason"
                case orderId = "order_id"
            }
        }

        let cancelResponse = try JSONDecoder().decode(BatchCancelResponse.self, from: data)

        guard !cancelResponse.results.isEmpty else {
            throw OrderError.invalidResponse
        }

        let failedResults = cancelResponse.results.filter { !$0.success }
        if failedResults.count == cancelResponse.results.count {
            let errorMessages = failedResults.compactMap { $0.failureReason ?? "Unknown error" }
            throw OrderError.apiError(errorMessages.joined(separator: "; "))
        }

        // Update order status locally for all successfully canceled orders
        DispatchQueue.main.async {
            for result in cancelResponse.results where result.success {
                if let orderId = result.orderId, let order = self.orders[orderId] {
                    let updatedOrder = Order(
                        id: order.id,
                        clientOrderId: order.clientOrderId,
                        productId: order.productId,
                        side: order.side,
                        orderType: order.orderType,
                        status: .canceled,
                        price: order.price,
                        size: order.size,
                        filledSize: order.filledSize,
                        averageFilledPrice: order.averageFilledPrice,
                        createdAt: order.createdAt,
                        updatedAt: Date(),
                        source: order.source,
                        stopPrice: order.stopPrice,
                        timeInForce: order.timeInForce,
                        postOnly: order.postOnly,
                        rejectReason: order.rejectReason,
                        algorithmId: order.algorithmId,
                        algorithmName: order.algorithmName,
                        targetCloseTime: order.targetCloseTime,
                        goalPnL: order.goalPnL,
                        actualPnL: order.actualPnL,
                        targetPrice: order.targetPrice,
                        totalFees: order.totalFees,
                        filledValue: order.filledValue,
                        totalValueAfterFees: order.totalValueAfterFees,
                        numberOfFills: order.numberOfFills,
                        lastFillTime: order.lastFillTime
                    )
                    self.addOrder(updatedOrder)
                    self.stopPolling(orderId: orderId)
                }
            }
        }

        if failedResults.count == cancelResponse.results.count {
            let errorMessages = failedResults.compactMap { $0.failureReason ?? "Unknown error" }
            throw OrderError.apiError(errorMessages.joined(separator: "; "))
        }
    }

    // MARK: - Order Status Polling

    private func startPolling(orderId: String) {
        stopPolling(orderId: orderId)

        let startTime = Date()

        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else {
                // If self is nil, we can't access pollingTimers, but the timer will be cleaned up
                // when the object is deallocated. We can't invalidate it here without capturing it.
                return
            }

            if let order = self.orders[orderId],
               [.filled, .canceled, .rejected, .expired].contains(order.status)
            {
                self.stopPolling(orderId: orderId)
                return
            }

            if Date().timeIntervalSince(startTime) > self.maxPollingDuration {
                self.stopPolling(orderId: orderId)
                return
            }

            if self.pollingPermissionErrors.contains(orderId) {
                return
            }

            Task {
                do {
                    let updatedOrder = try await self.fetchOrder(orderId: orderId)
                    DispatchQueue.main.async {
                        if let existingOrder = self.orders[orderId] {
                            if updatedOrder.status != existingOrder.status ||
                                updatedOrder.filledSize != existingOrder.filledSize
                            {
                                self.addOrder(updatedOrder)
                            }
                        }
                    }
                } catch {
                    if case let OrderError.httpError(statusCode) = error, statusCode == 403 {
                        DispatchQueue.main.async {
                            self.pollingPermissionErrors.insert(orderId)
                            self.stopPolling(orderId: orderId)
                        }
                    }
                }
            }
        }

        pollingTimers[orderId] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPolling(orderId: String) {
        pollingTimers[orderId]?.invalidate()
        pollingTimers.removeValue(forKey: orderId)
        pollingPermissionErrors.remove(orderId)
    }

    // MARK: - Order Management

    private func addOrder(_ order: Order) {
        orders[order.id] = order

        // Update by product
        if ordersByProduct[order.productId] == nil {
            ordersByProduct[order.productId] = []
        }
        if let index = ordersByProduct[order.productId]?.firstIndex(where: { $0.id == order.id }) {
            ordersByProduct[order.productId]?[index] = order
        } else {
            ordersByProduct[order.productId]?.append(order)
        }

        if let index = recentOrders.firstIndex(where: { $0.id == order.id }) {
            recentOrders[index] = order
        } else {
            recentOrders.insert(order, at: 0)
        }

        if recentOrders.count > maxRecentOrders {
            recentOrders = Array(recentOrders.prefix(maxRecentOrders))
        }

        recentOrders.sort { $0.createdAt > $1.createdAt }
    }

    // MARK: - Query Methods

    func getOrders(for productId: String) -> [Order] {
        return ordersByProduct[productId] ?? []
    }

    func getOrders(with status: OrderStatus) -> [Order] {
        return orders.values.filter { $0.status == status }
    }

    func getPendingOrders() -> [Order] {
        return orders.values.filter { [.pending, .open].contains($0.status) }
    }

    func getFilledOrders() -> [Order] {
        return orders.values.filter { $0.status == .filled }
    }

    func getCanceledOrders() -> [Order] {
        return orders.values.filter { $0.status == .canceled }
    }

    func getOpenOrders() -> [Order] {
        return orders.values.filter { $0.status == .open }
    }

    // MARK: - Coinbase API Conversion

    private func convertCoinbaseOrder(_ coinbaseOrder: CoinbaseOrder) throws -> Order {
        guard let side = OrderSide(rawValue: coinbaseOrder.side.uppercased()) else {
            throw OrderError.invalidData("Invalid order side: \(coinbaseOrder.side)")
        }

        // Map API status to our enum, handling CANCELLED vs CANCELED
        let statusString = coinbaseOrder.status.uppercased()
        let normalizedStatus: String
        if statusString == "CANCELLED" {
            normalizedStatus = "CANCELED"
        } else {
            normalizedStatus = statusString
        }

        guard let status = OrderStatus(rawValue: normalizedStatus) else {
            throw OrderError.invalidData("Invalid order status: \(coinbaseOrder.status) (normalized: \(normalizedStatus))")
        }

        let orderType: OrderType
        var price: Double? = nil
        var size: Double? = nil
        var stopPrice: Double? = nil
        var postOnly: Bool? = nil

        if let orderConfig = coinbaseOrder.orderConfiguration {
            if let limitConfig = orderConfig.limitLimitGTC {
                orderType = .limit
                price = Double(limitConfig.limitPrice ?? "")
                size = Double(limitConfig.baseSize ?? "")
                postOnly = limitConfig.postOnly
            } else if let marketConfig = orderConfig.marketMarketIOC {
                orderType = .market
                // Market orders might have quote_size or base_size
                size = nil // Market orders don't have a fixed size in the same way
            } else if let stopConfig = orderConfig.stopLossStopLossGTC {
                orderType = .stop
                size = Double(stopConfig.baseSize ?? "")
                stopPrice = Double(stopConfig.stopPrice ?? "")
            } else if let stopLimitConfig = orderConfig.stopLossStopLossLimitGTC {
                orderType = .stopLimit
                price = Double(stopLimitConfig.limitPrice ?? "")
                size = Double(stopLimitConfig.baseSize ?? "")
                stopPrice = Double(stopLimitConfig.stopPrice ?? "")
            } else {
                // Unknown configuration type, default to limit
                orderType = .limit
            }
        } else {
            orderType = .limit
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse last fill time if present
        let lastFillTime: Date? = {
            if let lastFillTimeString = coinbaseOrder.lastFillTime {
                return dateFormatter.date(from: lastFillTimeString)
            }
            return nil
        }()

        return Order(
            id: coinbaseOrder.orderId,
            clientOrderId: coinbaseOrder.clientOrderId,
            productId: coinbaseOrder.productId,
            side: side,
            orderType: orderType,
            status: status,
            price: price, // This is the limit price
            size: size,
            filledSize: Double(coinbaseOrder.filledSize ?? "0") ?? 0.0,
            averageFilledPrice: Double(coinbaseOrder.averageFilledPrice ?? ""), // Execution price
            createdAt: dateFormatter.date(from: coinbaseOrder.createdTime) ?? Date(),
            updatedAt: dateFormatter.date(from: coinbaseOrder.createdTime) ?? Date(),
            source: .manual,
            stopPrice: stopPrice,
            timeInForce: nil,
            postOnly: postOnly,
            rejectReason: coinbaseOrder.rejectReason,
            algorithmId: nil,
            algorithmName: nil,
            targetCloseTime: nil,
            goalPnL: nil,
            actualPnL: nil,
            targetPrice: nil,
            totalFees: Double(coinbaseOrder.totalFees ?? ""),
            filledValue: Double(coinbaseOrder.filledValue ?? ""), // Subtotal
            totalValueAfterFees: Double(coinbaseOrder.totalValueAfterFees ?? ""), // Total
            numberOfFills: Int(coinbaseOrder.numberOfFills ?? "0"),
            lastFillTime: lastFillTime
        )
    }
}

// MARK: - Coinbase API Models

private struct CoinbaseOrder: Codable {
    let orderId: String
    let productId: String
    let userId: String
    let orderConfiguration: OrderConfiguration?
    let side: String
    let clientOrderId: String?
    let status: String
    let filledSize: String?
    let averageFilledPrice: String?
    let orderPlacementSource: String
    let createdTime: String
    let rejectReason: String?
    let totalFees: String?
    let filledValue: String?
    let totalValueAfterFees: String?
    let numberOfFills: String?
    let lastFillTime: String?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case productId = "product_id"
        case userId = "user_id"
        case orderConfiguration = "order_configuration"
        case side
        case clientOrderId = "client_order_id"
        case status
        case filledSize = "filled_size"
        case averageFilledPrice = "average_filled_price"
        case orderPlacementSource = "order_placement_source"
        case createdTime = "created_time"
        case rejectReason = "reject_reason"
        case totalFees = "total_fees"
        case filledValue = "filled_value"
        case totalValueAfterFees = "total_value_after_fees"
        case numberOfFills = "number_of_fills"
        case lastFillTime = "last_fill_time"
    }
}

private struct OrderConfiguration: Codable {
    let limitLimitGTC: LimitOrderConfig?
    let marketMarketIOC: MarketOrderConfig?
    let stopLossStopLossGTC: StopOrderConfig?
    let stopLossStopLossLimitGTC: StopLimitOrderConfig?

    enum CodingKeys: String, CodingKey {
        case limitLimitGTC = "limit_limit_gtc"
        case marketMarketIOC = "market_market_ioc"
        case stopLossStopLossGTC = "stop_loss_stop_loss_gtc"
        case stopLossStopLossLimitGTC = "stop_loss_stop_loss_limit_gtc"
    }
}

private struct LimitOrderConfig: Codable {
    let baseSize: String?
    let limitPrice: String?
    let postOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case baseSize = "base_size"
        case limitPrice = "limit_price"
        case postOnly = "post_only"
    }
}

private struct MarketOrderConfig: Codable {
    let quoteSize: String?

    enum CodingKeys: String, CodingKey {
        case quoteSize = "quote_size"
    }
}

private struct StopOrderConfig: Codable {
    let baseSize: String?
    let stopPrice: String?

    enum CodingKeys: String, CodingKey {
        case baseSize = "base_size"
        case stopPrice = "stop_price"
    }
}

private struct StopLimitOrderConfig: Codable {
    let baseSize: String?
    let limitPrice: String?
    let stopPrice: String?

    enum CodingKeys: String, CodingKey {
        case baseSize = "base_size"
        case limitPrice = "limit_price"
        case stopPrice = "stop_price"
    }
}

// MARK: - Errors

enum OrderError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case let .httpError(code):
            return "HTTP error: \(code)"
        case let .apiError(message):
            return "API error: \(message)"
        case let .invalidData(message):
            return "Invalid data: \(message)"
        }
    }
}
