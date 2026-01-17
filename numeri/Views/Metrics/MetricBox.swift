//
//  MetricBox.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI
#if canImport(AppKit)
    import AppKit
#endif

struct MetricBox: View {
    let metric: Metric
    @State private var showInfo = false

    private var valueFontSize: CGFloat {
        let text = metric.formattedValue
        let length = text.count

        if length > 12 {
            return 11
        } else if length > 8 {
            return 13
        } else {
            return 15
        }
    }

    // Cross-platform background color that adapts to the system appearance
    private var backgroundColor: Color {
        #if canImport(UIKit)
            return Color(.systemGray6)
        #elseif canImport(AppKit)
            return Color(nsColor: .controlBackgroundColor)
        #else
            return Color(white: 0.95)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
            HStack(alignment: .top, spacing: TerminalTheme.paddingTiny) {
                Text(metric.type.rawValue.uppercased())
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny))
                    .foregroundColor(TerminalTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button(action: {
                    showInfo = true
                }) {
                    Text("?")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeTiny, weight: .bold))
                        .foregroundColor(TerminalTheme.textSecondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help(metric.type.description)
            }

            if metric.isAvailable {
                Text(metric.formattedValue)
                    .font(TerminalTheme.monospaced(size: valueFontSize, weight: .semibold))
                    .foregroundColor(TerminalTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(metric.formattedValue)
                    .font(TerminalTheme.monospaced(size: valueFontSize))
                    .foregroundColor(TerminalTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let latency = metric.latencyMs, latency >= 0 {
                Text("\(latency)ms")
                    .font(TerminalTheme.monospaced(size: 8))
                    .foregroundColor(TerminalTheme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, TerminalTheme.paddingSmall)
        .padding(.vertical, TerminalTheme.paddingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TerminalTheme.surface)
        .overlay(TerminalTheme.borderStyle())
        .popover(isPresented: $showInfo, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                Text(metric.type.rawValue.uppercased())
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                    .foregroundColor(TerminalTheme.textPrimary)

                Text(metric.type.description)
                    .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                    .foregroundColor(TerminalTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(TerminalTheme.paddingMedium)
            .frame(maxWidth: 250)
            .background(TerminalTheme.surface)
            .overlay(TerminalTheme.borderStyle())
        }
    }
}
