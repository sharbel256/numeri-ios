//
//  SuggestionsView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import SwiftUI

struct SuggestionsView: View {
    @ObservedObject var algorithmManager: AlgorithmMetricsManager
    @StateObject private var oauthManager = OAuthManager()
    @State private var orderManager: OrderExecutionManager?
    @State private var minConfidence: Double = 0.6
    @State private var selectedSide: OrderSide? = nil

    private var filteredSuggestions: [OrderSuggestion] {
        var suggestions = algorithmManager.getFilteredSuggestions(minConfidence: minConfidence)

        if let side = selectedSide {
            suggestions = suggestions.filter { $0.side == side }
        }

        // Sort by timestamp (newest first)
        return suggestions.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack {
            if oauthManager.accessToken == nil {
                LoginPromptView(showCredentialsAlert: .constant(false))
            } else {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                    // Header with filters
                    VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                            // Confidence filter
                            VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                                Text("MIN CONFIDENCE: \(Int(minConfidence * 100))%")
                                    .font(TerminalTheme.monospaced(size: 9))
                                    .foregroundColor(TerminalTheme.textSecondary)
                                Slider(value: $minConfidence, in: 0.0 ... 1.0)
                                    .tint(TerminalTheme.cyan)
                            }

                            // Side filter
                            Picker("Side", selection: $selectedSide) {
                                Text("ALL").tag(OrderSide?.none)
                                Text("BUY").tag(OrderSide?.some(.buy))
                                Text("SELL").tag(OrderSide?.some(.sell))
                            }
                            .pickerStyle(.segmented)
                            .font(TerminalTheme.monospaced(size: 9))
                        }
                    }
                    .padding(.horizontal, TerminalTheme.paddingSmall)

                    // Suggestions list
                    if filteredSuggestions.isEmpty {
                        VStack(spacing: TerminalTheme.paddingSmall) {
                            Text("💡")
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
        .onAppear {
            oauthManager.loadTokens()
            initializeOrderManager()
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            if newToken != nil {
                initializeOrderManager()
            } else {
                orderManager?.invalidateToken()
                orderManager = nil
            }
        }
    }

    private func initializeOrderManager() {
        if orderManager == nil, let token = oauthManager.accessToken {
            orderManager = OrderExecutionManager(accessToken: token) { [weak oauthManager] in
                guard let oauthManager = oauthManager else { return nil }
                let success = await oauthManager.refreshAccessToken()
                return success ? oauthManager.accessToken : nil
            }
            Task {
                try? await orderManager?.fetchOrders()
            }
        }
    }
}
