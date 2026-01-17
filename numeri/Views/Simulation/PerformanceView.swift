//
//  PerformanceView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import SwiftUI
#if canImport(Charts)
    import Charts
#endif

struct PerformanceView: View {
    @ObservedObject var simulationManager: SimulatedOrderManager
    let productId: String
    @State private var selectedAlgorithm: String? = nil
    @State private var timeRange: TimeRange = .all

    enum TimeRange {
        case day
        case week
        case month
        case all

        var displayName: String {
            switch self {
            case .day: return "24h"
            case .week: return "7d"
            case .month: return "30d"
            case .all: return "All"
            }
        }
    }

    private var metrics: PerformanceMetrics {
        // CRITICAL: Filter by productId to prevent cross-product contamination
        simulationManager.getPerformanceMetrics(for: selectedAlgorithm, productId: productId)
    }

    private var filteredData: [PerformanceDataPoint] {
        let cutoff: Date
        switch timeRange {
        case .day:
            cutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .week:
            cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .all:
            return metrics.historicalData
        }
        return metrics.historicalData.filter { $0.date >= cutoff }
    }

    private var cumulativePnL: [(Date, Double)] {
        var cumulative: Double = 0
        return filteredData.sorted { $0.date < $1.date }.map { point in
            cumulative += point.pnl
            return (point.date, cumulative)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TerminalTheme.paddingMedium) {
                // Summary cards
                HStack(spacing: TerminalTheme.paddingSmall) {
                    SummaryCard(
                        title: "TOTAL ORDERS",
                        value: "\(metrics.totalOrders)",
                        color: TerminalTheme.cyan
                    )

                    SummaryCard(
                        title: "WIN RATE",
                        value: "\(Int(metrics.winRate * 100))%",
                        color: metrics.winRate >= 0.5 ? TerminalTheme.green : TerminalTheme.red
                    )

                    SummaryCard(
                        title: "TOTAL P&L",
                        value: String(format: "$%.2f", metrics.totalPnL),
                        color: metrics.totalPnL >= 0 ? TerminalTheme.green : TerminalTheme.red
                    )

                    SummaryCard(
                        title: "AVG P&L",
                        value: String(format: "$%.2f", metrics.averagePnL),
                        color: metrics.averagePnL >= 0 ? TerminalTheme.green : TerminalTheme.red
                    )
                }
                .padding(.horizontal, TerminalTheme.paddingMedium)

                // Algorithm filter
                HStack {
                    Text("ALGORITHM:")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                        .foregroundColor(TerminalTheme.textSecondary)

                    Menu {
                        Button("ALL ALGORITHMS") {
                            selectedAlgorithm = nil
                        }
                        ForEach(metrics.algorithmPerformance.keys.sorted(), id: \.self) { algoId in
                            Button(algoId.uppercased()) {
                                selectedAlgorithm = algoId
                            }
                        }
                    } label: {
                        HStack {
                            Text((selectedAlgorithm ?? "ALL ALGORITHMS").uppercased())
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                            Text("▼")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        }
                        .foregroundColor(TerminalTheme.textPrimary)
                        .padding(.horizontal, TerminalTheme.paddingMedium)
                        .padding(.vertical, TerminalTheme.paddingSmall)
                        .background(TerminalTheme.surface)
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.border, lineWidth: 1)
                        )
                    }

                    Spacer()

                    // Time range picker
                    Picker("Range", selection: $timeRange) {
                        ForEach([TimeRange.day, .week, .month, .all], id: \.self) { range in
                            Text(range.displayName.uppercased()).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                    .frame(width: 200)
                }
                .padding(.horizontal, TerminalTheme.paddingMedium)

                // Cumulative P&L Chart
                if !cumulativePnL.isEmpty {
                    VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                        Text("CUMULATIVE P&L")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                            .foregroundColor(TerminalTheme.textPrimary)
                            .padding(.horizontal, TerminalTheme.paddingMedium)

                        #if canImport(Charts)
                            Chart {
                                ForEach(Array(cumulativePnL.enumerated()), id: \.offset) { _, point in
                                    LineMark(
                                        x: .value("Date", point.0),
                                        y: .value("P&L", point.1)
                                    )
                                    .foregroundStyle(point.1 >= 0 ? TerminalTheme.green : TerminalTheme.red)
                                    .interpolationMethod(.catmullRom)
                                }

                                // Zero line
                                RuleMark(y: .value("Zero", 0))
                                    .foregroundStyle(TerminalTheme.textSecondary.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            }
                            .frame(height: 200)
                            .padding(TerminalTheme.paddingMedium)
                            .background(TerminalTheme.surface)
                            .overlay(TerminalTheme.borderStyle())
                            .padding(.horizontal, TerminalTheme.paddingMedium)
                        #else
                            // Fallback for older iOS versions
                            VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                                ForEach(Array(cumulativePnL.suffix(10).enumerated()), id: \.offset) { _, point in
                                    HStack {
                                        Text(point.0, style: .time)
                                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                                            .foregroundColor(TerminalTheme.textSecondary)
                                        Spacer()
                                        Text(String(format: "$%.2f", point.1))
                                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .semibold))
                                            .foregroundColor(point.1 >= 0 ? TerminalTheme.green : TerminalTheme.red)
                                    }
                                }
                            }
                            .padding(TerminalTheme.paddingMedium)
                            .background(TerminalTheme.surface)
                            .overlay(TerminalTheme.borderStyle())
                            .padding(.horizontal, TerminalTheme.paddingMedium)
                        #endif
                    }
                }

                // Algorithm performance breakdown
                if !metrics.algorithmPerformance.isEmpty {
                    VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                        Text("ALGORITHM PERFORMANCE")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                            .foregroundColor(TerminalTheme.textPrimary)
                            .padding(.horizontal, TerminalTheme.paddingMedium)

                        ForEach(metrics.algorithmPerformance.keys.sorted(), id: \.self) { algoId in
                            if let algoPerf = metrics.algorithmPerformance[algoId] {
                                AlgorithmPerformanceCard(
                                    algorithmId: algoId,
                                    performance: algoPerf
                                )
                                .padding(.horizontal, TerminalTheme.paddingMedium)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, TerminalTheme.paddingMedium)
        }
        .background(TerminalTheme.background)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
            Text(title)
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                .foregroundColor(TerminalTheme.textSecondary)
            Text(value)
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TerminalTheme.paddingMedium)
        .background(TerminalTheme.surface)
        .overlay(TerminalTheme.borderStyle())
    }
}

struct AlgorithmPerformanceCard: View {
    let algorithmId: String
    let performance: AlgorithmPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            Text(algorithmId.uppercased())
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                .foregroundColor(TerminalTheme.textPrimary)

            HStack(spacing: TerminalTheme.paddingMedium) {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("ORDERS")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("\(performance.totalOrders)")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("WIN RATE")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text("\(Int(performance.winRate * 100))%")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(performance.winRate >= 0.5 ? TerminalTheme.green : TerminalTheme.red)
                }

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("TOTAL P&L")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text(String(format: "$%.2f", performance.totalPnL))
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(performance.totalPnL >= 0 ? TerminalTheme.green : TerminalTheme.red)
                }

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text("AVG P&L")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                    Text(String(format: "$%.2f", performance.averagePnL))
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(performance.averagePnL >= 0 ? TerminalTheme.green : TerminalTheme.red)
                }

                Spacer()
            }
        }
        .padding(TerminalTheme.paddingMedium)
        .background(TerminalTheme.surface)
        .overlay(TerminalTheme.borderStyle())
    }
}
