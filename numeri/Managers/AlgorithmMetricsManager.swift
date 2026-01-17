//
//  AlgorithmMetricsManager.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Combine
import Foundation

/// Manages all algorithm metrics and their order suggestions
class AlgorithmMetricsManager: ObservableObject {
    @Published private(set) var suggestions: [OrderSuggestion] = []
    @Published private(set) var newSuggestions: [OrderSuggestion] = [] // Published for simulation manager
    @Published private(set) var algorithmMetrics: [String: AlgorithmMetric] = [:]
    @Published private(set) var metricValues: [String: Double] = [:]

    private let calculationQueue = DispatchQueue(label: "com.numeri.algorithms.calculation", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var productId: String = ""

    init() {
        // Register default algorithms
        registerDefaultAlgorithms()
    }

    /// Register an algorithm metric
    func register(_ algorithm: AlgorithmMetric) {
        algorithmMetrics[algorithm.algorithmId] = algorithm
    }

    /// Unregister an algorithm metric
    func unregister(algorithmId: String) {
        algorithmMetrics.removeValue(forKey: algorithmId)
        metricValues.removeValue(forKey: algorithmId)
    }

    /// Get all registered algorithms
    func getAllAlgorithms() -> [AlgorithmMetric] {
        return Array(algorithmMetrics.values)
    }

    /// Get enabled algorithms only
    func getEnabledAlgorithms() -> [AlgorithmMetric] {
        return algorithmMetrics.values.filter { $0.isEnabled }
    }

    /// Process a new orderbook snapshot and calculate all algorithm metrics
    func processSnapshot(_ snapshot: OrderbookSnapshot, productId: String) {
        self.productId = productId

        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            var newSuggestions: [OrderSuggestion] = []
            var newMetricValues: [String: Double] = [:]

            // Calculate metrics for all enabled algorithms
            for algorithm in self.getEnabledAlgorithms() {
                if let metricValue = algorithm.calculate(snapshot: snapshot) {
                    newMetricValues[algorithm.algorithmId] = metricValue

                    // Generate suggestions with productId
                    // Algorithms now manage their own active suggestions internally
                    let algorithmSuggestions = algorithm.generateSuggestions(
                        metricValue: metricValue,
                        snapshot: snapshot,
                        productId: productId
                    )

                    newSuggestions.append(contentsOf: algorithmSuggestions)
                }
            }

            DispatchQueue.main.async {
                self.metricValues = newMetricValues

                // Build updated suggestions list:
                // 1. Keep existing suggestions that are still active (by ID or still in algorithm)
                // 2. Add/update new suggestions from algorithms
                // 3. Only remove suggestions that are no longer active in their algorithms

                var updatedSuggestions: [OrderSuggestion] = []
                var activeSuggestionIds: Set<UUID> = []

                // Collect IDs of new/updated suggestions
                for suggestion in newSuggestions {
                    activeSuggestionIds.insert(suggestion.id)
                }

                // Check which existing suggestions are still active in their algorithms
                var stillActiveIds: Set<UUID> = activeSuggestionIds
                for existingSuggestion in self.suggestions {
                    if let algorithm = self.algorithmMetrics[existingSuggestion.algorithmId] {
                        // Check if this suggestion is still active in the algorithm
                        let activeBuy = algorithm.getActiveSuggestion(for: .buy)
                        let activeSell = algorithm.getActiveSuggestion(for: .sell)
                        if activeBuy?.id == existingSuggestion.id || activeSell?.id == existingSuggestion.id {
                            stillActiveIds.insert(existingSuggestion.id)
                        }
                    }
                }

                // Keep existing suggestions that are still active
                for existingSuggestion in self.suggestions {
                    if stillActiveIds.contains(existingSuggestion.id) {
                        // Find the updated version if available
                        if let updated = newSuggestions.first(where: { $0.id == existingSuggestion.id }) {
                            updatedSuggestions.append(updated)
                        } else {
                            // Keep existing if no update available
                            updatedSuggestions.append(existingSuggestion)
                        }
                    }
                }

                // Add new suggestions that weren't in the existing list
                for newSuggestion in newSuggestions {
                    if !self.suggestions.contains(where: { $0.id == newSuggestion.id }) {
                        updatedSuggestions.append(newSuggestion)
                    }
                }

                // Sort by timestamp (newest first)
                updatedSuggestions.sort { $0.timestamp > $1.timestamp }

                // Find truly new suggestions (not in previous list)
                let previousIds = Set(self.suggestions.map { $0.id })
                let newSuggestions = updatedSuggestions.filter { !previousIds.contains($0.id) }

                self.suggestions = updatedSuggestions
                self.newSuggestions = newSuggestions
            }
        }
    }

    /// Reset all algorithms (e.g., when switching products)
    func reset() {
        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            for algorithm in self.algorithmMetrics.values {
                algorithm.reset()
            }

            DispatchQueue.main.async {
                self.suggestions.removeAll()
                self.metricValues.removeAll()
            }
        }
    }

    /// Get suggestions filtered by minimum confidence
    func getFilteredSuggestions(minConfidence: Double = 0.0) -> [OrderSuggestion] {
        return suggestions.filter {
            $0.confidence >= minConfidence
        }
    }

    /// Get suggestions for a specific side
    func getSuggestions(for side: OrderSide) -> [OrderSuggestion] {
        return suggestions.filter { $0.side == side }
    }

    /// Get expired suggestions that should be recorded as missed opportunities
    /// Only considers suggestions expired if their target close time has passed
    func getExpiredSuggestions() -> [OrderSuggestion] {
        let now = Date()
        return suggestions.filter { suggestion in
            // Only consider expired if target close time has passed
            if let targetTime = suggestion.targetCloseTime {
                return now >= targetTime
            }
            // If no target time, never expire automatically (only on explicit removal)
            return false
        }
    }

    /// Remove expired suggestions from the active list
    /// Only removes suggestions that have passed their target close time, not based on age
    func removeExpiredSuggestions() {
        let expired = getExpiredSuggestions()
        let expiredIds = Set(expired.map { $0.id })

        // Only remove suggestions that have truly expired (target close time passed)
        suggestions = suggestions.filter {
            !expiredIds.contains($0.id)
        }

        // Also remove from algorithm's active suggestions
        for algorithm in algorithmMetrics.values {
            for expiredId in expiredIds {
                algorithm.removeActiveSuggestion(id: expiredId)
            }
        }
    }

    /// Remove a suggestion when it's executed or ignored
    func removeSuggestion(_ suggestion: OrderSuggestion) {
        suggestions = suggestions.filter { $0.id != suggestion.id }

        // Remove from algorithm's active suggestions
        if let algorithm = algorithmMetrics[suggestion.algorithmId] {
            algorithm.removeActiveSuggestion(id: suggestion.id)
        }
    }

    /// Remove a suggestion by ID
    func removeSuggestion(id: UUID) {
        suggestions = suggestions.filter { $0.id != id }

        // Remove from all algorithms' active suggestions
        for algorithm in algorithmMetrics.values {
            algorithm.removeActiveSuggestion(id: id)
        }
    }

    private func registerDefaultAlgorithms() {
        // Register example algorithms - these can be moved to separate files
        register(ImbalanceAlgorithm())
        register(VelocityAlgorithm())
        // Add more algorithms as they're created
    }
}
