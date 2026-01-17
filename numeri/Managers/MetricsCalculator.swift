//
//  MetricsCalculator.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import Combine
import Foundation

class MetricsCalculator: ObservableObject {
    @Published private(set) var metrics: [MetricType: Metric] = [:]

    private let calculationQueue = DispatchQueue(label: "com.numeri.metrics.calculation", qos: .userInitiated)
    private var priceHistory: [(price: Double, volume: Double, timestamp: Date)] = []
    private var priceTimestamps: [(price: Double, timestamp: Date)] = []
    private var updateTimestamps: [Date] = []
    private let timeWindow: TimeInterval = 5 * 60
    private let velocityWindow: TimeInterval = 30
    private let flowRateWindow: TimeInterval = 10
    private let maxHistorySize = 1000

    init() {
        initializeAllMetrics()
    }

    private func initializeAllMetrics() {
        let allTypes: [MetricType] = [.orderBookImbalance, .vwap, .orderBookDepth, .priceVelocity, .orderFlowRate]
        for type in allTypes {
            metrics[type] = Metric(
                type: type,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }
    }

    func calculateMetrics(bids: [OrderbookEntry], offers: [OrderbookEntry], currentPrice: Double, latencyMs: Int? = nil) {
        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            let totalVolume = bids.reduce(0) { $0 + $1.quantity } + offers.reduce(0) { $0 + $1.quantity }
            if totalVolume > 0 {
                self.addToHistory(price: currentPrice, volume: totalVolume)
            }

            let now = Date()
            self.updateTimestamps.append(now)
            self.cleanUpdateTimestamps()

            self.priceTimestamps.append((price: currentPrice, timestamp: now))
            self.cleanPriceTimestamps()

            // Always return a Metric, never nil
            let imbalanceMetric = self.calculateOrderBookImbalance(bids: bids, offers: offers)
            let vwapMetric = self.calculateVWAP()
            let depthMetric = self.calculateOrderBookDepth(bids: bids, offers: offers)
            let velocityMetric = self.calculatePriceVelocity()
            let flowRateMetric = self.calculateOrderFlowRate()

            DispatchQueue.main.async {
                let updatedImbalance = Metric(
                    type: imbalanceMetric.type,
                    value: imbalanceMetric.value,
                    formattedValue: imbalanceMetric.formattedValue,
                    unit: imbalanceMetric.unit,
                    isAvailable: imbalanceMetric.isAvailable,
                    latencyMs: latencyMs
                )
                self.metrics[.orderBookImbalance] = updatedImbalance

                let updatedVwap = Metric(
                    type: vwapMetric.type,
                    value: vwapMetric.value,
                    formattedValue: vwapMetric.formattedValue,
                    unit: vwapMetric.unit,
                    isAvailable: vwapMetric.isAvailable,
                    latencyMs: latencyMs
                )
                self.metrics[.vwap] = updatedVwap

                let updatedDepth = Metric(
                    type: depthMetric.type,
                    value: depthMetric.value,
                    formattedValue: depthMetric.formattedValue,
                    unit: depthMetric.unit,
                    isAvailable: depthMetric.isAvailable,
                    latencyMs: latencyMs
                )
                self.metrics[.orderBookDepth] = updatedDepth

                let updatedVelocity = Metric(
                    type: velocityMetric.type,
                    value: velocityMetric.value,
                    formattedValue: velocityMetric.formattedValue,
                    unit: velocityMetric.unit,
                    isAvailable: velocityMetric.isAvailable,
                    latencyMs: latencyMs
                )
                self.metrics[.priceVelocity] = updatedVelocity

                let updatedFlowRate = Metric(
                    type: flowRateMetric.type,
                    value: flowRateMetric.value,
                    formattedValue: flowRateMetric.formattedValue,
                    unit: flowRateMetric.unit,
                    isAvailable: flowRateMetric.isAvailable,
                    latencyMs: latencyMs
                )
                self.metrics[.orderFlowRate] = updatedFlowRate
            }
        }
    }

    // Order Book Imbalance: Ratio of bid volume to ask volume
    private func calculateOrderBookImbalance(bids: [OrderbookEntry], offers: [OrderbookEntry]) -> Metric {
        let bidVolume = bids.reduce(0) { $0 + $1.quantity }
        let askVolume = offers.reduce(0) { $0 + $1.quantity }

        guard askVolume > 0 else {
            return Metric(
                type: .orderBookImbalance,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let imbalance = bidVolume / askVolume
        let percentage = (imbalance - 1.0) * 100

        let formattedValue: String
        if percentage > 0 {
            formattedValue = String(format: "+%.2f%%", percentage)
        } else {
            formattedValue = String(format: "%.2f%%", percentage)
        }

        return Metric(
            type: .orderBookImbalance,
            value: imbalance,
            formattedValue: formattedValue,
            unit: nil,
            isAvailable: true
        )
    }

    // Volume-Weighted Average Price over time window
    private func calculateVWAP() -> Metric {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        let recentHistory = priceHistory.filter { $0.timestamp >= cutoffTime }

        guard !recentHistory.isEmpty else {
            return Metric(
                type: .vwap,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let totalVolume = recentHistory.reduce(0) { $0 + $1.volume }
        guard totalVolume > 0 else {
            return Metric(
                type: .vwap,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let weightedSum = recentHistory.reduce(0) { $0 + ($1.price * $1.volume) }
        let vwap = weightedSum / totalVolume

        return Metric(
            type: .vwap,
            value: vwap,
            formattedValue: String(format: "%.2f", vwap),
            unit: nil,
            isAvailable: true
        )
    }

    private func addToHistory(price: Double, volume: Double) {
        priceHistory.append((price: price, volume: volume, timestamp: Date()))

        let cutoffTime = Date().addingTimeInterval(-timeWindow * 2)
        priceHistory = priceHistory.filter { $0.timestamp >= cutoffTime }

        if priceHistory.count > maxHistorySize {
            priceHistory.removeFirst(priceHistory.count - maxHistorySize)
        }
    }

    // Order Book Depth: Total volume at best bid and ask (top 5 levels)
    private func calculateOrderBookDepth(bids: [OrderbookEntry], offers: [OrderbookEntry]) -> Metric {
        let top5Bids = Array(bids.prefix(5))
        let top5Offers = Array(offers.prefix(5))

        let bidDepth = top5Bids.reduce(0) { $0 + $1.quantity }
        let askDepth = top5Offers.reduce(0) { $0 + $1.quantity }
        let totalDepth = bidDepth + askDepth

        guard totalDepth > 0 else {
            return Metric(
                type: .orderBookDepth,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        return Metric(
            type: .orderBookDepth,
            value: totalDepth,
            formattedValue: String(format: "%.2f", totalDepth),
            unit: nil,
            isAvailable: true
        )
    }

    // Price Velocity: Rate of price change over time
    private func calculatePriceVelocity() -> Metric {
        guard priceTimestamps.count >= 2 else {
            return Metric(
                type: .priceVelocity,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let cutoffTime = Date().addingTimeInterval(-velocityWindow)
        let recentPrices = priceTimestamps.filter { $0.timestamp >= cutoffTime }

        guard recentPrices.count >= 2,
              let oldest = recentPrices.first,
              let newest = recentPrices.last
        else {
            return Metric(
                type: .priceVelocity,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let timeDiff = newest.timestamp.timeIntervalSince(oldest.timestamp)
        guard timeDiff > 0 else {
            return Metric(
                type: .priceVelocity,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let priceDiff = newest.price - oldest.price
        let velocity = priceDiff / timeDiff

        let formattedValue: String
        if velocity >= 0 {
            formattedValue = String(format: "+$%.2f/s", velocity)
        } else {
            formattedValue = String(format: "$%.2f/s", velocity)
        }

        return Metric(
            type: .priceVelocity,
            value: velocity,
            formattedValue: formattedValue,
            unit: nil,
            isAvailable: true
        )
    }

    // Order Flow Rate: Number of updates per second
    private func calculateOrderFlowRate() -> Metric {
        let cutoffTime = Date().addingTimeInterval(-flowRateWindow)
        let recentUpdates = updateTimestamps.filter { $0 >= cutoffTime }

        guard !recentUpdates.isEmpty else {
            return Metric(
                type: .orderFlowRate,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }

        let flowRate = Double(recentUpdates.count) / flowRateWindow

        return Metric(
            type: .orderFlowRate,
            value: flowRate,
            formattedValue: String(format: "%.1f", flowRate),
            unit: "updates/s",
            isAvailable: true
        )
    }

    private func cleanPriceTimestamps() {
        let cutoffTime = Date().addingTimeInterval(-velocityWindow * 2)
        priceTimestamps = priceTimestamps.filter { $0.timestamp >= cutoffTime }

        if priceTimestamps.count > maxHistorySize {
            priceTimestamps.removeFirst(priceTimestamps.count - maxHistorySize)
        }
    }

    private func cleanUpdateTimestamps() {
        let cutoffTime = Date().addingTimeInterval(-flowRateWindow * 2)
        updateTimestamps = updateTimestamps.filter { $0 >= cutoffTime }

        if updateTimestamps.count > maxHistorySize {
            updateTimestamps.removeFirst(updateTimestamps.count - maxHistorySize)
        }
    }

    func reset() {
        calculationQueue.async { [weak self] in
            guard let self = self else { return }
            self.priceHistory.removeAll()
            self.priceTimestamps.removeAll()
            self.updateTimestamps.removeAll()
            DispatchQueue.main.async {
                self.initializeAllMetrics()
            }
        }
    }
}
