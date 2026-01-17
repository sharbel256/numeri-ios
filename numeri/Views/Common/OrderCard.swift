//
//  OrderCard.swift
//  numeri
//
//  Created by Sharbel Homa on 7/27/25.
//

import SwiftUI

struct OrderCard: View {
    let order: Order
    @ObservedObject var orderManager: OrderExecutionManager
    @State private var isExpanded = false
    @State private var isCanceling = false

    private var statusColor: Color {
        switch order.status {
        case .pending, .open:
            return .orange
        case .filled:
            return .green
        case .canceled, .rejected, .expired:
            return .red
        }
    }

    private var sideColor: Color {
        order.side == .buy ? .green : .red
    }

    private func formatCreatedTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        let days = Int(timeInterval / 86400)

        if days > 30 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let hours = Int(timeInterval / 3600)
            if hours > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
            } else {
                let minutes = Int(timeInterval / 60)
                if minutes > 0 {
                    return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
                } else {
                    return "Just now"
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
            HStack(alignment: .center, spacing: TerminalTheme.paddingSmall) {
                Text(order.side.rawValue.uppercased())
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, TerminalTheme.paddingTiny)
                    .padding(.vertical, 1)
                    .background(sideColor)

                Text(order.status.displayName.uppercased())
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, TerminalTheme.paddingTiny)
                    .padding(.vertical, 1)
                    .background(statusColor.opacity(0.15))
                    .overlay(
                        Rectangle()
                            .stroke(statusColor, lineWidth: 1)
                    )

                if order.source != .manual {
                    Text(order.source.displayName.uppercased())
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)
                        .padding(.horizontal, TerminalTheme.paddingTiny)
                        .padding(.vertical, 1)
                        .background(TerminalTheme.surface)
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.border, lineWidth: 1)
                        )
                }

                Text(order.productId)
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                    .foregroundColor(TerminalTheme.textSecondary)

                Text(formatCreatedTime(order.createdAt))
                    .font(TerminalTheme.monospaced(size: 9))
                    .foregroundColor(TerminalTheme.textSecondary)

                Spacer()

                HStack(spacing: TerminalTheme.paddingSmall) {
                    if let price = order.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                            .foregroundColor(TerminalTheme.textPrimary)
                    } else {
                        Text("MKT")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }

                    if let size = order.size {
                        Text("× \(size, specifier: "%.4f")")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                }

                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "−" : "+")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                        .foregroundColor(TerminalTheme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }

            if order.filledSize > 0 {
                HStack(spacing: TerminalTheme.paddingSmall) {
                    Text("FILLED: \(order.filledSize, specifier: "%.4f")")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                        .foregroundColor(TerminalTheme.textSecondary)

                    if let avgPrice = order.averageFilledPrice {
                        Text("AVG: $\(avgPrice)")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                }
            }

            if order.source == .missed {
                HStack(spacing: TerminalTheme.paddingMedium) {
                    if let goalPnL = order.goalPnL {
                        Text("GOAL: $\(goalPnL, specifier: "%.2f")")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }

                    if let actualPnL = order.actualPnL {
                        Text("ACTUAL: $\(actualPnL, specifier: "%.2f")")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                            .foregroundColor(actualPnL >= 0 ? TerminalTheme.green : TerminalTheme.red)
                    }

                    if let targetCloseTime = order.targetCloseTime {
                        if Date() >= targetCloseTime {
                            Text("TARGET: PASSED")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.amber)
                        } else {
                            Text("TARGET: \(targetCloseTime, style: .relative)")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, TerminalTheme.paddingTiny)
                .padding(.horizontal, TerminalTheme.paddingSmall)
                .background(TerminalTheme.amber.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(TerminalTheme.amber.opacity(0.3), lineWidth: 1)
                )
            }

            if isExpanded {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    HStack {
                        Text("ID:")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(order.id)
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                            .foregroundColor(TerminalTheme.textPrimary)
                            .textSelection(.enabled)
                    }

                    if let clientOrderId = order.clientOrderId {
                        HStack {
                            Text("CLIENT:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text(clientOrderId)
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                                .textSelection(.enabled)
                        }
                    }

                    HStack {
                        Text("TYPE:")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(order.orderType.displayName.uppercased())
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                            .foregroundColor(TerminalTheme.textPrimary)

                        Spacer()

                        Text("CREATED: \(formatCreatedTime(order.createdAt))")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                    
                    // Pricing information
                    if let limitPrice = order.price {
                        HStack {
                            Text("LIMIT PRICE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(limitPrice, specifier: "%.2f")")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    if let executionPrice = order.averageFilledPrice {
                        HStack {
                            Text("EXECUTION PRICE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(executionPrice)")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    // Fill information
                    if let numberOfFills = order.numberOfFills, numberOfFills > 0 {
                        HStack {
                            Text("FILLS:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("\(numberOfFills)")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    // Financial information
                    if let filledValue = order.filledValue {
                        HStack {
                            Text("SUBTOTAL:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(filledValue)")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    if let totalFees = order.totalFees {
                        HStack {
                            Text("FEE:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(totalFees)")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    if let total = order.totalValueAfterFees {
                        HStack {
                            Text("TOTAL:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(total)")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .bold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                    
                    // Time information
                    if let lastFillTime = order.lastFillTime {
                        HStack {
                            Text("LAST FILL:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text(formatCreatedTime(lastFillTime))
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }

                    if let rejectReason = order.rejectReason {
                        HStack {
                            Text("REJECTED:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.red)
                            Text(rejectReason.uppercased())
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.red)
                        }
                    }

                    if order.source == .missed, let targetPrice = order.targetPrice {
                        HStack {
                            Text("TARGET:")
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .medium))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                    }
                }
            }

            if [.pending, .open].contains(order.status) {
                Rectangle()
                    .fill(TerminalTheme.border)
                    .frame(height: 1)
                    .padding(.vertical, TerminalTheme.paddingTiny)

                Button(action: {
                    Task {
                        isCanceling = true
                        do {
                            try await orderManager.cancelOrder(orderId: order.id)
                        } catch {}
                        isCanceling = false
                    }
                }) {
                    HStack(spacing: TerminalTheme.paddingTiny) {
                        if isCanceling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(TerminalTheme.red)
                        } else {
                            Text("✕")
                                .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                        }
                        Text("CANCEL")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                    }
                    .foregroundColor(TerminalTheme.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TerminalTheme.paddingTiny)
                    .background(TerminalTheme.red.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.red, lineWidth: 1)
                    )
                }
                .disabled(isCanceling)
            }
        }
        .padding(.horizontal, TerminalTheme.paddingSmall)
        .padding(.vertical, TerminalTheme.paddingSmall)
        .background(TerminalTheme.surface)
        .overlay(
            Rectangle()
                .stroke(sideColor.opacity(0.5), lineWidth: 1)
        )
    }
}
