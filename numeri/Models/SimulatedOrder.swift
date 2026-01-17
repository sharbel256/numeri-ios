//
//  SimulatedOrder.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Foundation

/// Represents a simulated order that tracks performance without actual execution
struct SimulatedOrder: Identifiable, Codable {
    let id: String
    let algorithmId: String
    let algorithmName: String
    let productId: String
    let side: OrderSide
    let entryPrice: Double
    let size: Double
    let confidence: Double
    let reasoning: String
    let targetCloseTime: Date?
    let targetPrice: Double?
    let goalPnL: Double?
    let createdAt: Date
    var currentPrice: Double
    var actualPnL: Double
    var status: OrderStatus
    var closedAt: Date?
    var exitPrice: Double?
    var exitReason: ExitReason?

    enum CodingKeys: String, CodingKey {
        case id
        case algorithmId = "algorithm_id"
        case algorithmName = "algorithm_name"
        case productId = "product_id"
        case side
        case entryPrice = "entry_price"
        case size
        case confidence
        case reasoning
        case targetCloseTime = "target_close_time"
        case targetPrice = "target_price"
        case goalPnL = "goal_pnl"
        case createdAt = "created_at"
        case currentPrice = "current_price"
        case actualPnL = "actual_pnl"
        case status
        case closedAt = "closed_at"
        case exitPrice = "exit_price"
        case exitReason = "exit_reason"
    }

    init(
        id: String,
        algorithmId: String,
        algorithmName: String,
        productId: String,
        side: OrderSide,
        entryPrice: Double,
        size: Double,
        confidence: Double,
        reasoning: String,
        targetCloseTime: Date?,
        targetPrice: Double?,
        goalPnL: Double?,
        createdAt: Date,
        currentPrice: Double,
        actualPnL: Double,
        status: OrderStatus,
        closedAt: Date? = nil,
        exitPrice: Double? = nil,
        exitReason: ExitReason? = nil
    ) {
        self.id = id
        self.algorithmId = algorithmId
        self.algorithmName = algorithmName
        self.productId = productId
        self.side = side
        self.entryPrice = entryPrice
        self.size = size
        self.confidence = confidence
        self.reasoning = reasoning
        self.targetCloseTime = targetCloseTime
        self.targetPrice = targetPrice
        self.goalPnL = goalPnL
        self.createdAt = createdAt
        self.currentPrice = currentPrice
        self.actualPnL = actualPnL
        self.status = status
        self.closedAt = closedAt
        self.exitPrice = exitPrice
        self.exitReason = exitReason
    }
}

enum ExitReason: String, Codable {
    case targetTimeReached = "target_time_reached"
    case targetPriceReached = "target_price_reached"
    case manual

    var displayName: String {
        switch self {
        case .targetTimeReached:
            return "Target Time"
        case .targetPriceReached:
            return "Target Price"
        case .manual:
            return "Manual"
        }
    }
}

/// Performance metrics for tracking algorithm effectiveness
struct PerformanceMetrics: Codable {
    var totalOrders: Int = 0
    var winningTrades: Int = 0
    var losingTrades: Int = 0
    var totalPnL: Double = 0.0
    var algorithmPerformance: [String: AlgorithmPerformance] = [:]
    var historicalData: [PerformanceDataPoint] = []

    var winRate: Double {
        guard totalOrders > 0 else { return 0.0 }
        return Double(winningTrades) / Double(totalOrders)
    }

    var averagePnL: Double {
        guard totalOrders > 0 else { return 0.0 }
        return totalPnL / Double(totalOrders)
    }
}

struct AlgorithmPerformance: Codable {
    var totalOrders: Int = 0
    var winningTrades: Int = 0
    var losingTrades: Int = 0
    var totalPnL: Double = 0.0

    var winRate: Double {
        guard totalOrders > 0 else { return 0.0 }
        return Double(winningTrades) / Double(totalOrders)
    }

    var averagePnL: Double {
        guard totalOrders > 0 else { return 0.0 }
        return totalPnL / Double(totalOrders)
    }
}

struct PerformanceDataPoint: Codable {
    let date: Date
    let pnl: Double
    let algorithmId: String
}
