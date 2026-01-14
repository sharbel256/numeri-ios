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
        let column1 = Array(allMetrics.prefix(10))
        let column2 = Array(allMetrics.dropFirst(10))
        
        if column2.isEmpty {
            VStack(spacing: 8) {
                ForEach(column1, id: \.type) { metric in
                    MetricBox(metric: metric)
                        .id(metric.type)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity
                        ))
                }
            }
            .frame(width: 120)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allMetrics.count)
        } else {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 8) {
                    ForEach(column1, id: \.type) { metric in
                        MetricBox(metric: metric)
                            .id(metric.type)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                removal: .opacity
                            ))
                    }
                }
                .frame(width: 120)
                
                VStack(spacing: 8) {
                    ForEach(column2, id: \.type) { metric in
                        MetricBox(metric: metric)
                            .id(metric.type)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                removal: .opacity
                            ))
                    }
                }
                .frame(width: 120)
            }
            .frame(width: 248)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allMetrics.count)
        }
    }
}

