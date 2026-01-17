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
                GridItem(.flexible(minimum: 120), spacing: TerminalTheme.paddingSmall),
                GridItem(.flexible(minimum: 120), spacing: TerminalTheme.paddingSmall),
            ], spacing: TerminalTheme.paddingSmall) {
                ForEach(allMetrics, id: \.type) { metric in
                    MetricBox(metric: metric)
                        .id(metric.type)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, TerminalTheme.paddingSmall)
            .padding(.vertical, TerminalTheme.paddingSmall)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TerminalTheme.background)
    }
}
