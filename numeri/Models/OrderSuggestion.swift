//
//  OrderSuggestion.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation

/// Represents a suggested order based on algorithm analysis
struct OrderSuggestion: Identifiable {
    let id: UUID
    let algorithmName: String
    let algorithmId: String
    let side: OrderSide
    let productId: String
    let suggestedPrice: Double
    let suggestedSize: Double
    let confidence: Double // 0.0 to 1.0
    let reasoning: String
    let timestamp: Date
    let metricValue: Double? // The metric value that triggered this suggestion
    let targetCloseTime: Date? // When the algorithm expects to close this position
    let goalPnL: Double? // Expected profit/loss if executed and closed at target time
    let targetPrice: Double? // Target exit price for calculating PnL
    
    init(
        id: UUID = UUID(),
        algorithmName: String,
        algorithmId: String,
        side: OrderSide,
        productId: String,
        suggestedPrice: Double,
        suggestedSize: Double,
        confidence: Double,
        reasoning: String,
        timestamp: Date = Date(),
        metricValue: Double? = nil,
        targetCloseTime: Date? = nil,
        goalPnL: Double? = nil,
        targetPrice: Double? = nil
    ) {
        self.id = id
        self.algorithmName = algorithmName
        self.algorithmId = algorithmId
        self.side = side
        self.productId = productId
        self.suggestedPrice = suggestedPrice
        self.suggestedSize = suggestedSize
        self.confidence = confidence.clamped(to: 0.0...1.0)
        self.reasoning = reasoning
        self.timestamp = timestamp
        self.metricValue = metricValue
        self.targetCloseTime = targetCloseTime
        self.goalPnL = goalPnL
        self.targetPrice = targetPrice
    }
}

enum OrderSide: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

