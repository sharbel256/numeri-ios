//
//  LoginPromptView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct LoginPromptView: View {
    @Binding var showCredentialsAlert: Bool

    var body: some View {
        VStack(spacing: TerminalTheme.paddingMedium) {
            Text("⚠")
                .font(.system(size: 40))
                .foregroundColor(TerminalTheme.amber)

            Text("COINBASE LOGIN REQUIRED")
                .font(TerminalTheme.monospaced(size: 14, weight: .bold))
                .foregroundColor(TerminalTheme.textPrimary)

            Text("Please log in with Coinbase in the Settings tab to view the order book.")
                .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall))
                .foregroundColor(TerminalTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("GO TO SETTINGS") {
                showCredentialsAlert = true
            }
            .buttonStyle(TerminalActionButtonStyle(color: TerminalTheme.blue))
        }
        .padding(TerminalTheme.paddingLarge)
        .background(TerminalTheme.surface)
        .overlay(TerminalTheme.borderStyle())
    }
}
