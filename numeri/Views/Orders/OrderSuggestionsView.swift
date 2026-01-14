//
//  OrderSuggestionsView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import SwiftUI

struct OrderSuggestionsView: View {
    @ObservedObject var algorithmManager: AlgorithmMetricsManager
    let orderManager: OrderExecutionManager?
    @State private var minConfidence: Double = 0.6
    @State private var selectedSide: OrderSide? = nil
    
    init(algorithmManager: AlgorithmMetricsManager, orderManager: OrderExecutionManager? = nil) {
        self.algorithmManager = algorithmManager
        self.orderManager = orderManager
    }
    
    private var filteredSuggestions: [OrderSuggestion] {
        var suggestions = algorithmManager.getFilteredSuggestions(minConfidence: minConfidence)
        
        if let side = selectedSide {
            suggestions = suggestions.filter { $0.side == side }
        }
        
        // Sort by timestamp (newest first)
        return suggestions.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Order Suggestions")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    // Confidence filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min Confidence: \(Int(minConfidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $minConfidence, in: 0.0...1.0)
                            .frame(width: 150)
                    }
                    
                    // Side filter
                    Picker("Side", selection: $selectedSide) {
                        Text("All").tag(OrderSide?.none)
                        Text("Buy").tag(OrderSide?.some(.buy))
                        Text("Sell").tag(OrderSide?.some(.sell))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            // Suggestions list
            if filteredSuggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No suggestions available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Adjust confidence threshold or wait for signals")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSuggestions) { suggestion in
                            OrderSuggestionCard(
                                suggestion: suggestion,
                                orderManager: orderManager,
                                algorithmManager: algorithmManager
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }
}

struct OrderSuggestionCard: View {
    let suggestion: OrderSuggestion
    let orderManager: OrderExecutionManager?
    let algorithmManager: AlgorithmMetricsManager?
    @State private var isExpanded = false
    @State private var isExecuting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var confidenceColor: Color {
        if suggestion.confidence >= 0.8 {
            return .green
        } else if suggestion.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sideColor: Color {
        suggestion.side == .buy ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.algorithmName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        // Side badge
                        Text(suggestion.side.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sideColor)
                            .cornerRadius(4)
                        
                        // Confidence badge
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(confidenceColor.opacity(0.2))
                            .cornerRadius(4)
                        
                        // Time ago badge
                        Text(timeAgoString(from: suggestion.timestamp))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Price and size
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(suggestion.suggestedPrice, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(suggestion.suggestedSize, specifier: "%.4f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            // Expanded details
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasoning")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let metricValue = suggestion.metricValue {
                        HStack {
                            Text("Metric Value:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(metricValue, specifier: "%.4f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 4)
                    }
                    
                    if let targetCloseTime = suggestion.targetCloseTime {
                        HStack {
                            Text("Target Close:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(targetCloseTime, style: .relative)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if let goalPnL = suggestion.goalPnL {
                        HStack {
                            Text("Goal P&L:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(goalPnL, specifier: "%.2f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(goalPnL >= 0 ? .green : .red)
                        }
                    }
                    
                    if let targetPrice = suggestion.targetPrice {
                        HStack {
                            Text("Target Price:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Text("Product: \(suggestion.productId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Execute button
            if let orderManager = orderManager {
                Divider()
                
                Button(action: {
                    Task {
                        isExecuting = true
                        do {
                            _ = try await orderManager.executeSuggestion(suggestion)
                            // Success - order was created, remove the suggestion
                            algorithmManager?.removeSuggestion(suggestion)
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                        isExecuting = false
                    }
                }) {
                    HStack {
                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isExecuting ? "Executing..." : "Execute Order")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(sideColor)
                    .cornerRadius(6)
                }
                .disabled(isExecuting)
                .alert("Order Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(sideColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            let seconds = Int(interval)
            return "\(seconds)s ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

