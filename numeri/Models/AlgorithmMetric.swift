//
//  AlgorithmMetric.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation

/// Protocol for metrics that can suggest trading orders based on their calculations
protocol AlgorithmMetric: AnyObject {
    /// Unique identifier for this algorithm
    var algorithmId: String { get }

    /// Human-readable name for display
    var algorithmName: String { get }

    /// Description of what this algorithm does
    var algorithmDescription: String { get }

    /// Whether this algorithm is currently enabled
    var isEnabled: Bool { get set }

    /// Configuration parameters (can be customized per algorithm)
    var configuration: AlgorithmConfiguration { get set }

    /// Calculate the metric value from orderbook data
    /// - Returns: The calculated metric value, or nil if calculation is not possible
    func calculate(snapshot: OrderbookSnapshot) -> Double?

    /// Generate order suggestions based on the current metric value and orderbook state
    /// - Parameters:
    ///   - metricValue: The current calculated metric value
    ///   - snapshot: The current orderbook snapshot
    ///   - productId: The product ID for the suggestions
    /// - Returns: Array of order suggestions, empty if no suggestions
    func generateSuggestions(metricValue: Double, snapshot: OrderbookSnapshot, productId: String) -> [OrderSuggestion]

    /// Get active suggestion for a specific side
    func getActiveSuggestion(for side: OrderSide) -> OrderSuggestion?

    /// Set active suggestion for a specific side
    func setActiveSuggestion(_ suggestion: OrderSuggestion?, for side: OrderSide)

    /// Remove active suggestion for a specific side
    func removeActiveSuggestion(for side: OrderSide)

    /// Remove active suggestion by ID
    func removeActiveSuggestion(id: UUID)

    /// Update an existing suggestion with new values while preserving its ID and original timestamp
    func updateActiveSuggestion(_ suggestion: OrderSuggestion, for side: OrderSide)

    /// Reset any internal state (e.g., when switching products)
    func reset()
}

/// Configuration for algorithm metrics
struct AlgorithmConfiguration: Codable {
    /// Minimum confidence threshold (0.0-1.0) for generating suggestions
    var minConfidence: Double

    /// Minimum order size
    var minOrderSize: Double

    /// Maximum order size
    var maxOrderSize: Double

    /// Custom parameters specific to each algorithm
    var customParameters: [String: Double]

    static let `default` = AlgorithmConfiguration(
        minConfidence: 0.6,
        minOrderSize: 0.001,
        maxOrderSize: 1.0,
        customParameters: [:]
    )
}

/// Base implementation that algorithms can extend
class BaseAlgorithmMetric: AlgorithmMetric {
    let algorithmId: String
    let algorithmName: String
    let algorithmDescription: String
    var isEnabled: Bool = true
    var configuration: AlgorithmConfiguration = .default

    // Track active suggestions: one per side (buy/sell)
    private var activeBuySuggestion: OrderSuggestion?
    private var activeSellSuggestion: OrderSuggestion?

    init(
        algorithmId: String,
        algorithmName: String,
        algorithmDescription: String,
        configuration: AlgorithmConfiguration = .default
    ) {
        self.algorithmId = algorithmId
        self.algorithmName = algorithmName
        self.algorithmDescription = algorithmDescription
        self.configuration = configuration
    }

    func calculate(snapshot _: OrderbookSnapshot) -> Double? {
        fatalError("Subclasses must implement calculate(snapshot:)")
    }

    func generateSuggestions(metricValue _: Double, snapshot _: OrderbookSnapshot, productId _: String) -> [OrderSuggestion] {
        return []
    }

    /// Get active suggestion for a specific side
    func getActiveSuggestion(for side: OrderSide) -> OrderSuggestion? {
        return side == .buy ? activeBuySuggestion : activeSellSuggestion
    }

    /// Set active suggestion for a specific side
    func setActiveSuggestion(_ suggestion: OrderSuggestion?, for side: OrderSide) {
        if side == .buy {
            activeBuySuggestion = suggestion
        } else {
            activeSellSuggestion = suggestion
        }
    }

    /// Remove active suggestion for a specific side
    func removeActiveSuggestion(for side: OrderSide) {
        setActiveSuggestion(nil, for: side)
    }

    /// Remove active suggestion by ID
    func removeActiveSuggestion(id: UUID) {
        if activeBuySuggestion?.id == id {
            activeBuySuggestion = nil
        }
        if activeSellSuggestion?.id == id {
            activeSellSuggestion = nil
        }
    }

    /// Update an existing suggestion with new values while preserving its ID and original timestamp
    func updateActiveSuggestion(_ suggestion: OrderSuggestion, for side: OrderSide) {
        // Get existing suggestion to preserve ID and timestamp
        let existing = getActiveSuggestion(for: side)
        let updated = OrderSuggestion(
            id: existing?.id ?? suggestion.id,
            algorithmName: suggestion.algorithmName,
            algorithmId: suggestion.algorithmId,
            side: suggestion.side,
            productId: suggestion.productId,
            suggestedPrice: suggestion.suggestedPrice,
            suggestedSize: suggestion.suggestedSize,
            confidence: suggestion.confidence,
            reasoning: suggestion.reasoning,
            timestamp: existing?.timestamp ?? suggestion.timestamp,
            metricValue: suggestion.metricValue,
            targetCloseTime: suggestion.targetCloseTime,
            goalPnL: suggestion.goalPnL,
            targetPrice: suggestion.targetPrice
        )
        setActiveSuggestion(updated, for: side)
    }

    func reset() {
        activeBuySuggestion = nil
        activeSellSuggestion = nil
    }
}
