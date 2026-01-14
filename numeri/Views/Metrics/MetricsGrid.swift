//
//  MetricsGrid.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct MetricsGrid: View {
    @ObservedObject var metricsCalculator: MetricsCalculator
    
    private var allMetricTypes: [MetricType] {
        [.orderBookImbalance, .vwap, .orderBookDepth, .priceVelocity, .orderFlowRate]
    }
    
    private var allMetrics: [Metric] {
        allMetricTypes.map { type in
            metricsCalculator.metrics[type] ?? Metric(
                type: type,
                value: 0,
                formattedValue: "Calculating...",
                unit: nil,
                isAvailable: false
            )
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(allMetrics, id: \.type) { metric in
                    MetricBox(metric: metric)
                        .id(metric.type)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity
                        ))
                }
            }
            .padding()
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allMetrics.count)
        }
    }
}

