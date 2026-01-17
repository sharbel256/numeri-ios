//
//  FeeInfoView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import SwiftUI

struct FeeInfoView: View {
    @ObservedObject var feeService: FeeService

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
            Text("FEE INFORMATION")
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                .foregroundColor(TerminalTheme.textSecondary)
                .padding(.bottom, TerminalTheme.paddingSmall)

            if feeService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(TerminalTheme.cyan)
                    Text("LOADING FEE DATA...")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                        .foregroundColor(TerminalTheme.textSecondary)
                }
            } else if let summary = feeService.transactionSummary {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    // Pricing Tier
                    FeeRow(
                        label: "PRICING TIER",
                        value: summary.feeTier.pricingTier,
                        color: TerminalTheme.cyan
                    )

                    // Maker Fee Rate
                    FeeRow(
                        label: "MAKER FEE",
                        value: String(format: "%.4f%%", summary.feeTier.makerFeeRateDouble * 100),
                        color: TerminalTheme.green
                    )

                    // Taker Fee Rate
                    FeeRow(
                        label: "TAKER FEE",
                        value: String(format: "%.4f%%", summary.feeTier.takerFeeRateDouble * 100),
                        color: TerminalTheme.amber
                    )

                    // Total Fees
                    if summary.totalFees > 0 {
                        FeeRow(
                            label: "TOTAL FEES (USD)",
                            value: String(format: "$%.2f", summary.totalFees),
                            color: TerminalTheme.textPrimary
                        )
                    }

                    // Total Volume
                    if let totalVolume = summary.totalVolume, totalVolume > 0 {
                        FeeRow(
                            label: "TOTAL VOLUME (USD)",
                            value: String(format: "$%.2f", totalVolume),
                            color: TerminalTheme.textSecondary
                        )
                    }
                }
            } else if let error = feeService.error {
                Text("ERROR: \(error)")
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                    .foregroundColor(TerminalTheme.red)
            } else {
                Text("NO FEE DATA AVAILABLE")
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                    .foregroundColor(TerminalTheme.textSecondary)
            }
        }
        .padding(TerminalTheme.paddingMedium)
        .background(TerminalTheme.surface)
        .overlay(
            Rectangle()
                .stroke(TerminalTheme.border, lineWidth: 1)
        )
    }
}

struct FeeRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                .foregroundColor(TerminalTheme.textSecondary)
            Spacer()
            Text(value)
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
