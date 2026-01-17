//
//  ImbalanceAlgorithm.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation

/// Algorithm that suggests orders based on orderbook imbalance
class ImbalanceAlgorithm: BaseAlgorithmMetric {
    private var history: [(value: Double, timestamp: Date)] = []
    private let historyWindow: TimeInterval = 60 // 1 minute

    init() {
        super.init(
            algorithmId: "imbalance",
            algorithmName: "Orderbook Imbalance",
            algorithmDescription: "Suggests orders when bid/ask volume imbalance exceeds thresholds"
        )

        // Custom configuration
        configuration.minConfidence = 0.65
        configuration.customParameters = [
            "buyThreshold": 1.2, // Buy when bid/ask > 1.2
            "sellThreshold": 0.8, // Sell when bid/ask < 0.8
            "maxSizePercent": 0.1, // Max 10% of best level size
        ]
    }

    override func calculate(snapshot: OrderbookSnapshot) -> Double? {
        let bidVolume = snapshot.bids.reduce(0) { $0 + $1.quantity }
        let askVolume = snapshot.offers.reduce(0) { $0 + $1.quantity }

        guard askVolume > 0 else { return nil }

        let imbalance = bidVolume / askVolume

        // Track history
        history.append((imbalance, Date()))
        cleanHistory()

        return imbalance
    }

    override func generateSuggestions(metricValue: Double, snapshot: OrderbookSnapshot, productId: String) -> [OrderSuggestion] {
        guard let midPrice = snapshot.midPrice else { return [] }

        let buyThreshold = configuration.customParameters["buyThreshold"] ?? 1.2
        let sellThreshold = configuration.customParameters["sellThreshold"] ?? 0.8
        let maxSizePercent = configuration.customParameters["maxSizePercent"] ?? 0.1

        var suggestions: [OrderSuggestion] = []

        // Buy signal: High bid volume relative to ask volume
        // Check if we have an existing buy suggestion
        let existingBuySuggestion = getActiveSuggestion(for: .buy)

        if metricValue > buyThreshold {
            let confidence = min(0.95, 0.5 + (metricValue - buyThreshold) * 0.3)

            if confidence >= configuration.minConfidence {
                let bestAsk = snapshot.offers.first
                let suggestedPrice = bestAsk?.price ?? midPrice
                let maxSize = (bestAsk?.quantity ?? 0) * maxSizePercent
                let suggestedSize = min(maxSize, configuration.maxOrderSize)

                if suggestedSize >= configuration.minOrderSize {
                    // Calculate target: expect imbalance to normalize in 5-15 minutes
                    // Target price: 2-5% profit based on confidence
                    let targetCloseTime = Date().addingTimeInterval(TimeInterval(5 * 60 + Int(confidence * 10 * 60))) // 5-15 minutes
                    let profitPercent = 0.02 + (confidence - 0.65) * 0.05 // 2-5% profit
                    let targetPrice = suggestedPrice * (1.0 + profitPercent)
                    let goalPnL = (targetPrice - suggestedPrice) * suggestedSize

                    let newSuggestion = OrderSuggestion(
                        algorithmName: algorithmName,
                        algorithmId: algorithmId,
                        side: .buy,
                        productId: productId,
                        suggestedPrice: suggestedPrice,
                        suggestedSize: suggestedSize,
                        confidence: confidence,
                        reasoning: "Bid volume is \(String(format: "%.1f", metricValue))x ask volume, indicating buying pressure",
                        metricValue: metricValue,
                        targetCloseTime: targetCloseTime,
                        goalPnL: goalPnL,
                        targetPrice: targetPrice
                    )

                    // Update existing or create new
                    if existingBuySuggestion != nil {
                        updateActiveSuggestion(newSuggestion, for: .buy)
                        suggestions.append(getActiveSuggestion(for: .buy)!)
                    } else {
                        setActiveSuggestion(newSuggestion, for: .buy)
                        suggestions.append(newSuggestion)
                    }
                } else if let existing = existingBuySuggestion {
                    // Keep existing suggestion even if size is too small now
                    suggestions.append(existing)
                }
            } else if let existing = existingBuySuggestion {
                // Confidence dropped but keep existing suggestion
                suggestions.append(existing)
            }
        } else if let existing = existingBuySuggestion {
            // Metric value no longer meets threshold, but keep existing suggestion
            suggestions.append(existing)
        }

        // Sell signal: Low bid volume relative to ask volume
        // Check if we have an existing sell suggestion
        let existingSellSuggestion = getActiveSuggestion(for: .sell)

        if metricValue < sellThreshold {
            let confidence = min(0.95, 0.5 + (sellThreshold - metricValue) * 0.3)

            if confidence >= configuration.minConfidence {
                let bestBid = snapshot.bids.first
                let suggestedPrice = bestBid?.price ?? midPrice
                let maxSize = (bestBid?.quantity ?? 0) * maxSizePercent
                let suggestedSize = min(maxSize, configuration.maxOrderSize)

                if suggestedSize >= configuration.minOrderSize {
                    // Calculate target: expect imbalance to normalize in 5-15 minutes
                    // Target price: 2-5% profit based on confidence
                    let targetCloseTime = Date().addingTimeInterval(TimeInterval(5 * 60 + Int(confidence * 10 * 60))) // 5-15 minutes
                    let profitPercent = 0.02 + (confidence - 0.65) * 0.05 // 2-5% profit
                    let targetPrice = suggestedPrice * (1.0 - profitPercent) // Lower price for sell
                    let goalPnL = (suggestedPrice - targetPrice) * suggestedSize

                    let newSuggestion = OrderSuggestion(
                        algorithmName: algorithmName,
                        algorithmId: algorithmId,
                        side: .sell,
                        productId: productId,
                        suggestedPrice: suggestedPrice,
                        suggestedSize: suggestedSize,
                        confidence: confidence,
                        reasoning: "Ask volume is \(String(format: "%.1f", 1.0 / metricValue))x bid volume, indicating selling pressure",
                        metricValue: metricValue,
                        targetCloseTime: targetCloseTime,
                        goalPnL: goalPnL,
                        targetPrice: targetPrice
                    )

                    // Update existing or create new
                    if existingSellSuggestion != nil {
                        updateActiveSuggestion(newSuggestion, for: .sell)
                        suggestions.append(getActiveSuggestion(for: .sell)!)
                    } else {
                        setActiveSuggestion(newSuggestion, for: .sell)
                        suggestions.append(newSuggestion)
                    }
                } else if let existing = existingSellSuggestion {
                    // Keep existing suggestion even if size is too small now
                    suggestions.append(existing)
                }
            } else if let existing = existingSellSuggestion {
                // Confidence dropped but keep existing suggestion
                suggestions.append(existing)
            }
        } else if let existing = existingSellSuggestion {
            // Metric value no longer meets threshold, but keep existing suggestion
            suggestions.append(existing)
        }

        return suggestions
    }

    override func reset() {
        history.removeAll()
    }

    private func cleanHistory() {
        let cutoff = Date().addingTimeInterval(-historyWindow)
        history = history.filter { $0.timestamp >= cutoff }
    }
}
