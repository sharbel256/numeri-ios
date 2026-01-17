//
//  VelocityAlgorithm.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation

/// Algorithm that suggests orders based on orderbook level sweep rate and liquidity consumption
class VelocityAlgorithm: BaseAlgorithmMetric {
    private var previousSnapshot: OrderbookSnapshot?
    private var consumptionHistory: [(value: Double, timestamp: Date)] = []
    private let historyWindow: TimeInterval = 30 // 30 seconds

    init() {
        super.init(
            algorithmId: "velocity",
            algorithmName: "Liquidity Sweep Velocity",
            algorithmDescription: "Suggests orders when price levels are being rapidly swept and liquidity consumed"
        )

        // Custom configuration
        configuration.minConfidence = 0.7
        configuration.customParameters = [
            "buySweepThreshold": 5.0, // 5 levels/second indicates buy pressure
            "sellSweepThreshold": -5.0, // -5 levels/second indicates sell pressure
            "liquidityWeight": 0.5, // Weight for liquidity consumption (0-1, rest is level count)
            "sizeMultiplier": 0.05, // 5% of typical order size
        ]
    }

    override func calculate(snapshot: OrderbookSnapshot) -> Double? {
        guard let previous = previousSnapshot else {
            previousSnapshot = snapshot
            return nil
        }

        let timeDiff = snapshot.timestamp.timeIntervalSince(previous.timestamp)
        guard timeDiff > 0 else {
            previousSnapshot = snapshot
            return nil
        }

        // Calculate how many bid levels were consumed (sell pressure)
        let bidLevelsConsumed = countConsumedLevels(
            previous: previous.bids,
            current: snapshot.bids,
            isBid: true
        )

        // Calculate how many ask levels were consumed (buy pressure)
        let askLevelsConsumed = countConsumedLevels(
            previous: previous.offers,
            current: snapshot.offers,
            isBid: false
        )

        // Calculate liquidity consumption
        let bidLiquidityConsumed = calculateLiquidityConsumed(
            previous: previous.bids,
            current: snapshot.bids
        )

        let askLiquidityConsumed = calculateLiquidityConsumed(
            previous: previous.offers,
            current: snapshot.offers
        )

        // Combine metrics: positive = buy pressure (asks consumed), negative = sell pressure (bids consumed)
        let liquidityWeight = configuration.customParameters["liquidityWeight"] ?? 0.5
        let levelWeight = 1.0 - liquidityWeight

        // Normalize liquidity consumption (per second, scaled by typical orderbook depth)
        let avgDepth = (snapshot.bids.prefix(5).reduce(0) { $0 + $1.quantity } +
            snapshot.offers.prefix(5).reduce(0) { $0 + $1.quantity }) / 10.0
        let normalizedBidLiquidity = avgDepth > 0 ? (bidLiquidityConsumed / timeDiff) / avgDepth : 0
        let normalizedAskLiquidity = avgDepth > 0 ? (askLiquidityConsumed / timeDiff) / avgDepth : 0

        // Level sweep rate (levels per second)
        let bidLevelRate = Double(bidLevelsConsumed) / timeDiff
        let askLevelRate = Double(askLevelsConsumed) / timeDiff

        // Combined metric: buy pressure is positive, sell pressure is negative
        let buyPressure = (askLevelRate * levelWeight) + (normalizedAskLiquidity * liquidityWeight * 10.0)
        let sellPressure = (bidLevelRate * levelWeight) + (normalizedBidLiquidity * liquidityWeight * 10.0)

        let velocity = buyPressure - sellPressure

        // Track history for smoothing
        consumptionHistory.append((velocity, snapshot.timestamp))
        cleanHistory()

        previousSnapshot = snapshot

        return velocity
    }

    override func generateSuggestions(metricValue: Double, snapshot: OrderbookSnapshot, productId: String) -> [OrderSuggestion] {
        guard let midPrice = snapshot.midPrice else { return [] }

        let buyThreshold = configuration.customParameters["buySweepThreshold"] ?? 5.0
        let sellThreshold = configuration.customParameters["sellSweepThreshold"] ?? -5.0
        let sizeMultiplier = configuration.customParameters["sizeMultiplier"] ?? 0.05

        var suggestions: [OrderSuggestion] = []

        // Buy signal: Strong ask level consumption (buy pressure)
        // Check if we have an existing buy suggestion
        let existingBuySuggestion = getActiveSuggestion(for: .buy)

        if metricValue > buyThreshold {
            let confidence = min(0.95, 0.6 + (metricValue - buyThreshold) * 0.1)

            if confidence >= configuration.minConfidence {
                let bestAsk = snapshot.offers.first
                let suggestedPrice = bestAsk?.price ?? midPrice

                // Size based on average orderbook depth
                let avgDepth = (snapshot.bids.prefix(5).reduce(0) { $0 + $1.quantity } +
                    snapshot.offers.prefix(5).reduce(0) { $0 + $1.quantity }) / 10.0
                let suggestedSize = min(avgDepth * sizeMultiplier, configuration.maxOrderSize)

                if suggestedSize >= configuration.minOrderSize {
                    // Calculate target: aggressive sweeps typically continue for 1-5 minutes
                    let timeWindow = TimeInterval(1 * 60 + Int(confidence * 4 * 60)) // 1-5 minutes
                    let targetCloseTime = Date().addingTimeInterval(timeWindow)

                    // Estimate price movement based on sweep rate (rough approximation)
                    // Higher sweep rate suggests more aggressive buying, estimate 0.1% per unit of metric
                    let estimatedPriceMove = suggestedPrice * (metricValue * 0.001)
                    let targetPrice = suggestedPrice + estimatedPriceMove
                    let goalPnL = (targetPrice - suggestedPrice) * suggestedSize

                    let newSuggestion = OrderSuggestion(
                        algorithmName: algorithmName,
                        algorithmId: algorithmId,
                        side: .buy,
                        productId: productId,
                        suggestedPrice: suggestedPrice,
                        suggestedSize: suggestedSize,
                        confidence: confidence,
                        reasoning: "Ask levels being swept at \(String(format: "%.2f", metricValue)) levels/sec - aggressive buy pressure",
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

        // Sell signal: Strong bid level consumption (sell pressure)
        // Check if we have an existing sell suggestion
        let existingSellSuggestion = getActiveSuggestion(for: .sell)

        if metricValue < sellThreshold {
            let confidence = min(0.95, 0.6 + abs(metricValue - sellThreshold) * 0.1)

            if confidence >= configuration.minConfidence {
                let bestBid = snapshot.bids.first
                let suggestedPrice = bestBid?.price ?? midPrice

                // Size based on average orderbook depth
                let avgDepth = (snapshot.bids.prefix(5).reduce(0) { $0 + $1.quantity } +
                    snapshot.offers.prefix(5).reduce(0) { $0 + $1.quantity }) / 10.0
                let suggestedSize = min(avgDepth * sizeMultiplier, configuration.maxOrderSize)

                if suggestedSize >= configuration.minOrderSize {
                    // Calculate target: aggressive sweeps typically continue for 1-5 minutes
                    let timeWindow = TimeInterval(1 * 60 + Int(confidence * 4 * 60)) // 1-5 minutes
                    let targetCloseTime = Date().addingTimeInterval(timeWindow)

                    // Estimate price movement based on sweep rate (rough approximation)
                    // Higher sweep rate suggests more aggressive selling, estimate 0.1% per unit of metric
                    let estimatedPriceMove = suggestedPrice * (abs(metricValue) * 0.001)
                    let targetPrice = suggestedPrice - estimatedPriceMove
                    let goalPnL = (suggestedPrice - targetPrice) * suggestedSize

                    let newSuggestion = OrderSuggestion(
                        algorithmName: algorithmName,
                        algorithmId: algorithmId,
                        side: .sell,
                        productId: productId,
                        suggestedPrice: suggestedPrice,
                        suggestedSize: suggestedSize,
                        confidence: confidence,
                        reasoning: "Bid levels being swept at \(String(format: "%.2f", abs(metricValue))) levels/sec - aggressive sell pressure",
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
        previousSnapshot = nil
        consumptionHistory.removeAll()
    }

    private func cleanHistory() {
        let cutoff = Date().addingTimeInterval(-historyWindow)
        consumptionHistory = consumptionHistory.filter { $0.timestamp >= cutoff }
    }

    /// Count how many price levels were consumed (swept through) between snapshots
    private func countConsumedLevels(previous: [OrderbookEntry], current: [OrderbookEntry], isBid _: Bool) -> Int {
        guard !previous.isEmpty && !current.isEmpty else { return 0 }

        // For bids: higher prices are better, so we check if previous best prices are gone
        // For asks: lower prices are better, so we check if previous best prices are gone
        let previousBestPrices = Set(previous.prefix(10).map { $0.price })
        let currentBestPrices = Set(current.prefix(10).map { $0.price })

        // Count how many previous best prices are no longer in current best prices
        let consumedCount = previousBestPrices.subtracting(currentBestPrices).count

        return consumedCount
    }

    /// Calculate total liquidity consumed between snapshots
    private func calculateLiquidityConsumed(previous: [OrderbookEntry], current: [OrderbookEntry]) -> Double {
        guard !previous.isEmpty else { return 0 }

        var consumed: Double = 0

        // Check top 10 levels
        for prevEntry in previous.prefix(10) {
            // Find matching price level in current snapshot
            if let currentEntry = current.first(where: { $0.price == prevEntry.price }) {
                // If quantity decreased, that's consumption
                if currentEntry.quantity < prevEntry.quantity {
                    consumed += prevEntry.quantity - currentEntry.quantity
                }
            } else {
                // Price level completely gone, all liquidity consumed
                consumed += prevEntry.quantity
            }
        }

        return consumed
    }
}
