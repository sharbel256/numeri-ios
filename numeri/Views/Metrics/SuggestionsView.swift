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
                VStack(alignment: .leading, spacing: 12) {
                    // Header with filters
                    VStack(alignment: .leading, spacing: 8) {
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
                            Image(systemName: "lightbulb")
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

