//
//  OrderbookRow.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct OrderbookRow: View {
    let entry: OrderbookEntry
    let type: OrderBookType
    let maxQuantity: Double

    private var isPlaceholder: Bool {
        entry.price == 0.0 && entry.quantity == 0.0
    }

    private var fillColor: Color {
        if isPlaceholder {
            return Color.clear
        }
        return type == .bid ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
    }

    private var textColor: Color {
        if isPlaceholder {
            return .secondary
        }
        return type == .bid ? .green : .red
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .fill(fillColor.opacity(0.3))
                .frame(width: progressWidth)

            if isPlaceholder {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(TerminalTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, TerminalTheme.paddingTiny)
            } else {
                HStack {
                    Text("$\(entry.price, specifier: "%.2f")")
                        .foregroundColor(textColor)
                        .frame(width: 80, alignment: .leading)

                    Text("\(entry.quantity, specifier: "%.8f")")
                        .foregroundColor(TerminalTheme.textPrimary)
                        .frame(width: 80, alignment: .trailing)
                }
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                .padding(.vertical, TerminalTheme.paddingTiny)
            }
        }
        .frame(height: 20)
        .overlay(
            Rectangle()
                .stroke(TerminalTheme.border.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var progressWidth: CGFloat {
        let maxAmount = max(maxQuantity, entry.quantity, 1.0)
        return CGFloat(entry.quantity / maxAmount) * 160
    }
}
