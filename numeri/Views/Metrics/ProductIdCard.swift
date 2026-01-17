//
//  ProductIdCard.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

struct ProductIdCard: View {
    @State var productId: String
    @Binding var productIds: [String]
    @Binding var selectedProductId: String
    @State private var showDeleteConfirmation = false

    private var isSelected: Bool {
        selectedProductId == productId
    }

    private func performHapticFeedback() {
        #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        #elseif canImport(AppKit)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }

    var body: some View {
        Text(productId)
            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .medium))
            .foregroundColor(isSelected ? .black : TerminalTheme.textPrimary)
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(isSelected ? TerminalTheme.cyan : TerminalTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? TerminalTheme.cyan : TerminalTheme.border, lineWidth: 1)
            )
            .onTapGesture {
                selectedProductId = productId
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if productIds.count > 1 {
                    performHapticFeedback()
                    showDeleteConfirmation = true
                }
            }
            .alert("REMOVE PRODUCT", isPresented: $showDeleteConfirmation) {
                Button("CANCEL", role: .cancel) {}
                Button("REMOVE", role: .destructive) {
                    productIds.removeAll { $0 == productId }
                    if selectedProductId == productId {
                        selectedProductId = productIds.first ?? ""
                    }
                }
            } message: {
                Text("Are you sure you want to remove \(productId)?")
            }
    }
}
