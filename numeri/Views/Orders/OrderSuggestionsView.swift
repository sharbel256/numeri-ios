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
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            // Header with filters
            VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                Text("ORDER SUGGESTIONS")
                    .font(TerminalTheme.monospaced(size: 12, weight: .bold))
                    .foregroundColor(TerminalTheme.textPrimary)

                HStack(spacing: TerminalTheme.paddingSmall) {
                    // Confidence filter
                    VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                        Text("MIN CONFIDENCE: \(Int(minConfidence * 100))%")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Slider(value: $minConfidence, in: 0.0 ... 1.0)
                            .frame(width: 150)
                            .tint(TerminalTheme.cyan)
                    }

                    // Side filter
                    Picker("Side", selection: $selectedSide) {
                        Text("ALL").tag(OrderSide?.none)
                        Text("BUY").tag(OrderSide?.some(.buy))
                        Text("SELL").tag(OrderSide?.some(.sell))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .font(TerminalTheme.monospaced(size: 9))

                    Spacer()
                }
            }
            .padding(.horizontal, TerminalTheme.paddingSmall)

            // Suggestions list
            if filteredSuggestions.isEmpty {
                VStack(spacing: TerminalTheme.paddingSmall) {
                    Text("📈")
                        .font(.system(size: 30))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("NO SUGGESTIONS AVAILABLE")
                        .font(TerminalTheme.monospaced(size: 10, weight: .medium))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("ADJUST CONFIDENCE THRESHOLD OR WAIT FOR SIGNALS")
                        .font(TerminalTheme.monospaced(size: 9))
                        .foregroundColor(TerminalTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(TerminalTheme.paddingSmall)
            } else {
                ScrollView {
                    LazyVStack(spacing: TerminalTheme.paddingSmall) {
                        ForEach(filteredSuggestions) { suggestion in
                            OrderSuggestionCard(
                                suggestion: suggestion,
                                orderManager: orderManager,
                                algorithmManager: algorithmManager
                            )
                        }
                    }
                    .padding(.horizontal, TerminalTheme.paddingSmall)
                    .padding(.bottom, TerminalTheme.paddingSmall)
                }
            }
        }
        .background(TerminalTheme.background)
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
            return TerminalTheme.green
        } else if suggestion.confidence >= 0.6 {
            return TerminalTheme.amber
        } else {
            return TerminalTheme.red
        }
    }

    private var sideColor: Color {
        suggestion.side == .buy ? TerminalTheme.green : TerminalTheme.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text(suggestion.algorithmName.uppercased())
                        .font(TerminalTheme.monospaced(size: 10, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)

                    HStack(spacing: TerminalTheme.paddingSmall) {
                        // Side badge
                        Text(suggestion.side.rawValue.uppercased())
                            .font(TerminalTheme.monospaced(size: 8, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background(sideColor)

                        // Confidence badge
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(TerminalTheme.monospaced(size: 8, weight: .semibold))
                            .foregroundColor(confidenceColor)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background(confidenceColor.opacity(0.15))
                            .overlay(
                                Rectangle()
                                    .stroke(confidenceColor, lineWidth: 1)
                            )

                        // Time ago badge
                        Text(timeAgoString(from: suggestion.timestamp).uppercased())
                            .font(TerminalTheme.monospaced(size: 8, weight: .medium))
                            .foregroundColor(TerminalTheme.textSecondary)
                            .padding(.horizontal, TerminalTheme.paddingTiny)
                            .padding(.vertical, 1)
                            .background(TerminalTheme.surface)
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.border, lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "−" : "+")
                        .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                        .foregroundColor(TerminalTheme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }

            // Price and size
            HStack {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("PRICE")
                        .font(TerminalTheme.monospaced(size: 8))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("$\(suggestion.suggestedPrice, specifier: "%.2f")")
                        .font(TerminalTheme.monospaced(size: 11, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: TerminalTheme.paddingTiny) {
                    Text("SIZE")
                        .font(TerminalTheme.monospaced(size: 8))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("\(suggestion.suggestedSize, specifier: "%.4f")")
                        .font(TerminalTheme.monospaced(size: 11, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }
            }

            // Expanded details
            if isExpanded {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("REASONING")
                        .font(TerminalTheme.monospaced(size: 8, weight: .semibold))
                        .foregroundColor(TerminalTheme.textSecondary)

                    Text(suggestion.reasoning.uppercased())
                        .font(TerminalTheme.monospaced(size: 9))
                        .foregroundColor(TerminalTheme.textSecondary)

                    if let metricValue = suggestion.metricValue {
                        HStack {
                            Text("METRIC VALUE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("\(metricValue, specifier: "%.4f")")
                                .font(TerminalTheme.monospaced(size: 9, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }

                    if let targetCloseTime = suggestion.targetCloseTime {
                        HStack {
                            Text("TARGET CLOSE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text(targetCloseTime, style: .relative)
                                .font(TerminalTheme.monospaced(size: 9, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }

                    if let goalPnL = suggestion.goalPnL {
                        HStack {
                            Text("GOAL P&L:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(goalPnL, specifier: "%.2f")")
                                .font(TerminalTheme.monospaced(size: 9, weight: .semibold))
                                .foregroundColor(goalPnL >= 0 ? TerminalTheme.green : TerminalTheme.red)
                        }
                    }

                    if let targetPrice = suggestion.targetPrice {
                        HStack {
                            Text("TARGET PRICE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(TerminalTheme.monospaced(size: 9, weight: .semibold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }

                    Text("PRODUCT: \(suggestion.productId)")
                        .font(TerminalTheme.monospaced(size: 9))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
            }

            // Execute button
            if let orderManager = orderManager {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

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
                    HStack(spacing: TerminalTheme.paddingTiny) {
                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.black)
                        } else {
                            Text("↑")
                                .font(TerminalTheme.monospaced(size: 12, weight: .bold))
                        }
                        Text(isExecuting ? "EXECUTING..." : "EXECUTE ORDER")
                            .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TerminalTheme.paddingSmall)
                    .background(sideColor)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.border, lineWidth: 1)
                    )
                }
                .disabled(isExecuting)
                .alert("ORDER ERROR", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
        }
        .padding(TerminalTheme.paddingSmall)
        .background(TerminalTheme.surface)
        .overlay(
            Rectangle()
                .stroke(sideColor.opacity(0.5), lineWidth: 1)
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
