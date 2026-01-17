//
//  MetricsSidebar.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct MetricsSidebar: View {
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
        VStack(spacing: TerminalTheme.paddingSmall) {
            ForEach(allMetrics, id: \.type) { metric in
                MetricBox(metric: metric)
                    .id(metric.type)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
