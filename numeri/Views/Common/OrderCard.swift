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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text(order.side.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(sideColor)
                    .cornerRadius(3)
                
                Text(order.status.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(3)
                
                if order.source != .manual {
                    Text(order.source.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray5))
                        .cornerRadius(2)
                }
                
                Text(order.productId)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatCreatedTime(order.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let price = order.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                    } else {
                        Text("Market")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let size = order.size {
                        Text("× \(size, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if order.filledSize > 0 {
                HStack(spacing: 8) {
                    Text("Filled: \(order.filledSize, specifier: "%.4f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let avgPrice = order.averageFilledPrice {
                        Text("Avg: $\(avgPrice, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if order.source == .missed {
                HStack(spacing: 12) {
                    if let goalPnL = order.goalPnL {
                        Text("Goal: $\(goalPnL, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let actualPnL = order.actualPnL {
                        Text("Actual: $\(actualPnL, specifier: "%.2f")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(actualPnL >= 0 ? .green : .red)
                    }
                    
                    if let targetCloseTime = order.targetCloseTime {
                        if Date() >= targetCloseTime {
                            Text("Target: Passed")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("Target: \(targetCloseTime, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }
            
            if isExpanded {
                Divider()
                    .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("ID:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(order.id)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                    }
                    
                    if let clientOrderId = order.clientOrderId {
                        HStack {
                            Text("Client:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(clientOrderId)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textSelection(.enabled)
                        }
                    }
                    
                    HStack {
                        Text("Type:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(order.orderType.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Created: \(formatCreatedTime(order.createdAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let rejectReason = order.rejectReason {
                        HStack {
                            Text("Rejected:")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text(rejectReason)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if order.source == .missed, let targetPrice = order.targetPrice {
                        HStack {
                            Text("Target:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            
            if [.pending, .open].contains(order.status) {
                Divider()
                    .padding(.vertical, 2)
                
                Button(action: {
                    Task {
                        isCanceling = true
                        do {
                            try await orderManager.cancelOrder(orderId: order.id)
                        } catch {
                        }
                        isCanceling = false
                    }
                }) {
                    HStack(spacing: 4) {
                        if isCanceling {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "xmark.circle")
                                .font(.caption2)
                        }
                        Text("Cancel")
                            .font(.caption2)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .disabled(isCanceling)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(sideColor.opacity(0.3), lineWidth: 1)
        )
    }
}

