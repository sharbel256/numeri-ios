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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text(metric.type.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                Button(action: {
                    showInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help(metric.type.description)
            }
            
            if metric.isAvailable {
                Text(metric.formattedValue)
                    .font(.system(size: valueFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(metric.formattedValue)
                    .font(.system(size: valueFontSize))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            if let latency = metric.latencyMs, latency >= 0 {
                Text("\(latency)ms")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(8)
        .popover(isPresented: $showInfo, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.type.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(metric.type.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 250)
        }
    }
}

