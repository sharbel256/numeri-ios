//
//  Metric.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import Foundation

enum MetricType: String, Identifiable {
    case orderBookImbalance = "Order Book Imbalance"
    case vwap = "VWAP"
    case orderBookDepth = "Order Book Depth"
    case priceVelocity = "Price Velocity"
    case orderFlowRate = "Order Flow Rate"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .orderBookImbalance:
            return "The ratio of bid volume to ask volume. Values > 1.0 indicate more buying pressure, < 1.0 indicate more selling pressure."
        case .vwap:
            return "Volume-Weighted Average Price over the last 5 minutes. Shows the average price weighted by trading volume."
        case .orderBookDepth:
            return "Total volume available at the top 5 bid and ask levels. Higher depth indicates more liquidity."
        case .priceVelocity:
            return "The rate of price change per second. Positive values indicate upward momentum, negative values indicate downward momentum."
        case .orderFlowRate:
            return "The number of orderbook updates per second. Higher rates indicate more active trading activity."
        }
    }
}

struct Metric: Identifiable {
    let id: UUID
    let type: MetricType
    let value: Double
    let formattedValue: String
    let unit: String?
    let isAvailable: Bool
    let timestamp: Date
    let latencyMs: Int?
    
    init(type: MetricType, value: Double, formattedValue: String, unit: String? = nil, isAvailable: Bool = true, latencyMs: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.formattedValue = formattedValue
        self.unit = unit
        self.isAvailable = isAvailable
        self.timestamp = Date()
        self.latencyMs = latencyMs
    }
}

