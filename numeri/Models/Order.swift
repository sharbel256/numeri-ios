//
//  Order.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Foundation

/// Represents an actual trading order (not a suggestion)
struct Order: Identifiable, Codable {
    let id: String // Coinbase order ID
    let clientOrderId: String? // Our internal order ID
    let productId: String
    let side: OrderSide
    let orderType: OrderType
    let status: OrderStatus
    let price: Double?
    let size: Double?
    let filledSize: Double
    let averageFilledPrice: Double?
    let createdAt: Date
    let updatedAt: Date
    let source: OrderSource // Where the order came from

    // Optional fields
    let stopPrice: Double? // For stop orders
    let timeInForce: TimeInForce?
    let postOnly: Bool?
    let rejectReason: String?
    
    // Additional fields from Coinbase API
    let totalFees: Double? // Total fees for the order
    let filledValue: Double? // Subtotal: portion filled in quote currency
    let totalValueAfterFees: Double? // Total: filled value after fees
    let numberOfFills: Int? // Number of fills that have been posted
    let lastFillTime: Date? // Time of the most recent fill

    // Metadata
    let algorithmId: String? // If created from algorithm suggestion
    let algorithmName: String? // If created from algorithm suggestion

    // For missed opportunities
    let targetCloseTime: Date? // When the algorithm expected to close this position
    let goalPnL: Double? // Expected profit/loss if executed
    let actualPnL: Double? // Actual PnL if we track the price at target close time
    let targetPrice: Double? // Target exit price

    enum CodingKeys: String, CodingKey {
        case id
        case clientOrderId = "client_order_id"
        case productId = "product_id"
        case side
        case orderType = "order_type"
        case status
        case price
        case size
        case filledSize = "filled_size"
        case averageFilledPrice = "average_filled_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
        case stopPrice = "stop_price"
        case timeInForce = "time_in_force"
        case postOnly = "post_only"
        case rejectReason = "reject_reason"
        case algorithmId = "algorithm_id"
        case algorithmName = "algorithm_name"
        case targetCloseTime = "target_close_time"
        case goalPnL = "goal_pnl"
        case actualPnL = "actual_pnl"
        case targetPrice = "target_price"
        case totalFees = "total_fees"
        case filledValue = "filled_value"
        case totalValueAfterFees = "total_value_after_fees"
        case numberOfFills = "number_of_fills"
        case lastFillTime = "last_fill_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        clientOrderId = try container.decodeIfPresent(String.self, forKey: .clientOrderId)
        productId = try container.decode(String.self, forKey: .productId)
        side = try container.decode(OrderSide.self, forKey: .side)
        orderType = try container.decode(OrderType.self, forKey: .orderType)
        status = try container.decode(OrderStatus.self, forKey: .status)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        size = try container.decodeIfPresent(Double.self, forKey: .size)
        filledSize = try container.decode(Double.self, forKey: .filledSize)
        averageFilledPrice = try container.decodeIfPresent(Double.self, forKey: .averageFilledPrice)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        source = try container.decode(OrderSource.self, forKey: .source)
        stopPrice = try container.decodeIfPresent(Double.self, forKey: .stopPrice)
        timeInForce = try container.decodeIfPresent(TimeInForce.self, forKey: .timeInForce)
        postOnly = try container.decodeIfPresent(Bool.self, forKey: .postOnly)
        rejectReason = try container.decodeIfPresent(String.self, forKey: .rejectReason)
        algorithmId = try container.decodeIfPresent(String.self, forKey: .algorithmId)
        algorithmName = try container.decodeIfPresent(String.self, forKey: .algorithmName)
        targetCloseTime = try container.decodeIfPresent(Date.self, forKey: .targetCloseTime)
        goalPnL = try container.decodeIfPresent(Double.self, forKey: .goalPnL)
        actualPnL = try container.decodeIfPresent(Double.self, forKey: .actualPnL)
        targetPrice = try container.decodeIfPresent(Double.self, forKey: .targetPrice)
        totalFees = try container.decodeIfPresent(Double.self, forKey: .totalFees)
        filledValue = try container.decodeIfPresent(Double.self, forKey: .filledValue)
        totalValueAfterFees = try container.decodeIfPresent(Double.self, forKey: .totalValueAfterFees)
        numberOfFills = try container.decodeIfPresent(Int.self, forKey: .numberOfFills)
        lastFillTime = try container.decodeIfPresent(Date.self, forKey: .lastFillTime)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(clientOrderId, forKey: .clientOrderId)
        try container.encode(productId, forKey: .productId)
        try container.encode(side, forKey: .side)
        try container.encode(orderType, forKey: .orderType)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(price, forKey: .price)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encode(filledSize, forKey: .filledSize)
        try container.encodeIfPresent(averageFilledPrice, forKey: .averageFilledPrice)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(stopPrice, forKey: .stopPrice)
        try container.encodeIfPresent(timeInForce, forKey: .timeInForce)
        try container.encodeIfPresent(postOnly, forKey: .postOnly)
        try container.encodeIfPresent(rejectReason, forKey: .rejectReason)
        try container.encodeIfPresent(algorithmId, forKey: .algorithmId)
        try container.encodeIfPresent(algorithmName, forKey: .algorithmName)
        try container.encodeIfPresent(targetCloseTime, forKey: .targetCloseTime)
        try container.encodeIfPresent(goalPnL, forKey: .goalPnL)
        try container.encodeIfPresent(actualPnL, forKey: .actualPnL)
        try container.encodeIfPresent(targetPrice, forKey: .targetPrice)
        try container.encodeIfPresent(totalFees, forKey: .totalFees)
        try container.encodeIfPresent(filledValue, forKey: .filledValue)
        try container.encodeIfPresent(totalValueAfterFees, forKey: .totalValueAfterFees)
        try container.encodeIfPresent(numberOfFills, forKey: .numberOfFills)
        try container.encodeIfPresent(lastFillTime, forKey: .lastFillTime)
    }

    init(
        id: String,
        clientOrderId: String? = nil,
        productId: String,
        side: OrderSide,
        orderType: OrderType,
        status: OrderStatus,
        price: Double? = nil,
        size: Double? = nil,
        filledSize: Double = 0.0,
        averageFilledPrice: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: OrderSource,
        stopPrice: Double? = nil,
        timeInForce: TimeInForce? = nil,
        postOnly: Bool? = nil,
        rejectReason: String? = nil,
        algorithmId: String? = nil,
        algorithmName: String? = nil,
        targetCloseTime: Date? = nil,
        goalPnL: Double? = nil,
        actualPnL: Double? = nil,
        targetPrice: Double? = nil,
        totalFees: Double? = nil,
        filledValue: Double? = nil,
        totalValueAfterFees: Double? = nil,
        numberOfFills: Int? = nil,
        lastFillTime: Date? = nil
    ) {
        self.id = id
        self.clientOrderId = clientOrderId
        self.productId = productId
        self.side = side
        self.orderType = orderType
        self.status = status
        self.price = price
        self.size = size
        self.filledSize = filledSize
        self.averageFilledPrice = averageFilledPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.stopPrice = stopPrice
        self.timeInForce = timeInForce
        self.postOnly = postOnly
        self.rejectReason = rejectReason
        self.algorithmId = algorithmId
        self.algorithmName = algorithmName
        self.targetCloseTime = targetCloseTime
        self.goalPnL = goalPnL
        self.actualPnL = actualPnL
        self.targetPrice = targetPrice
        self.totalFees = totalFees
        self.filledValue = filledValue
        self.totalValueAfterFees = totalValueAfterFees
        self.numberOfFills = numberOfFills
        self.lastFillTime = lastFillTime
    }
}

enum OrderStatus: String, Codable {
    case pending = "PENDING"
    case open = "OPEN"
    case filled = "FILLED"
    case canceled = "CANCELED"
    case rejected = "REJECTED"
    case expired = "EXPIRED"

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .pending, .open:
            return "orange"
        case .filled:
            return "green"
        case .canceled, .rejected, .expired:
            return "red"
        }
    }
}

enum OrderType: String, Codable {
    case market = "MARKET"
    case limit = "LIMIT"
    case stop = "STOP"
    case stopLimit = "STOP_LIMIT"

    var displayName: String {
        switch self {
        case .stopLimit:
            return "Stop Limit"
        default:
            return rawValue.capitalized
        }
    }
}

enum TimeInForce: String, Codable {
    case gtc = "GTC" // Good Till Canceled
    case gtd = "GTD" // Good Till Date
    case ioc = "IOC" // Immediate Or Cancel
    case fok = "FOK" // Fill Or Kill
}

enum OrderSource: String, Codable {
    case manual
    case algorithm
    case suggestion
    case missed // A suggestion that was not executed

    var displayName: String {
        switch self {
        case .missed:
            return "Missed Opportunity"
        default:
            return rawValue.capitalized
        }
    }
}

/// Request to create a new order
struct CreateOrderRequest: Codable {
    let productId: String
    let side: OrderSide
    let orderType: OrderType
    let price: Double?
    let size: Double?
    let stopPrice: Double?
    let timeInForce: TimeInForce?
    let postOnly: Bool?
    let clientOrderId: String?

    init(
        productId: String,
        side: OrderSide,
        orderType: OrderType,
        price: Double? = nil,
        size: Double? = nil,
        stopPrice: Double? = nil,
        timeInForce: TimeInForce? = nil,
        postOnly: Bool? = nil,
        clientOrderId: String? = nil
    ) {
        self.productId = productId
        self.side = side
        self.orderType = orderType
        self.price = price
        self.size = size
        self.stopPrice = stopPrice
        self.timeInForce = timeInForce
        self.postOnly = postOnly
        self.clientOrderId = clientOrderId
    }

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case side
        case orderType = "order_configuration"
        case price
        case size
        case stopPrice = "stop_price"
        case timeInForce = "time_in_force"
        case postOnly = "post_only"
        case clientOrderId = "client_order_id"
    }

    func toCoinbaseJSON() -> [String: Any] {
        var json: [String: Any] = [
            "product_id": productId,
            "side": side.rawValue,
        ]

        // Order configuration based on type
        var orderConfig: [String: Any] = [:]

        switch orderType {
        case .market:
            if let size = size {
                orderConfig["market_market_ioc"] = ["quote_size": String(size)]
            }
        case .limit:
            var limitConfig: [String: Any] = [:]
            if let price = price {
                limitConfig["base_size"] = String(size ?? 0)
                limitConfig["limit_price"] = String(price)
            }
            if let tif = timeInForce {
                limitConfig["time_in_force"] = tif.rawValue
            }
            if let postOnly = postOnly {
                limitConfig["post_only"] = postOnly
            }
            orderConfig["limit_limit_gtc"] = limitConfig
        case .stop:
            var stopConfig: [String: Any] = [:]
            if let stopPrice = stopPrice {
                stopConfig["base_size"] = String(size ?? 0)
                stopConfig["stop_price"] = String(stopPrice)
            }
            orderConfig["stop_loss_stop_loss_gtc"] = stopConfig
        case .stopLimit:
            var stopLimitConfig: [String: Any] = [:]
            if let price = price, let stopPrice = stopPrice {
                stopLimitConfig["base_size"] = String(size ?? 0)
                stopLimitConfig["limit_price"] = String(price)
                stopLimitConfig["stop_price"] = String(stopPrice)
            }
            orderConfig["stop_loss_stop_loss_limit_gtc"] = stopLimitConfig
        }

        json["order_configuration"] = orderConfig

        if let clientOrderId = clientOrderId {
            json["client_order_id"] = clientOrderId
        }

        return json
    }
}

/// Response from Coinbase API when creating an order
struct CreateOrderResponse: Codable {
    let success: Bool
    let failureReason: String?
    let orderId: String?
    let successResponse: OrderResponse?
    let errorResponse: ErrorResponse?

    enum CodingKeys: String, CodingKey {
        case success
        case failureReason = "failure_reason"
        case orderId = "order_id"
        case successResponse = "success_response"
        case errorResponse = "error_response"
    }
}

struct OrderResponse: Codable {
    let orderId: String
    let productId: String
    let side: String
    let clientOrderId: String?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case productId = "product_id"
        case side
        case clientOrderId = "client_order_id"
    }
}

struct ErrorResponse: Codable {
    let error: String
    let message: String?
    let errorDetails: String?

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case errorDetails = "error_details"
    }
}
