//
//  SettingsView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    @StateObject private var oauthManager = OAuthManager()
    @State private var showSuccessAlert: Bool = false
    @State private var showClearDataConfirmation: Bool = false

    // Top 5 accounts sorted by balance value
    private var topAccounts: [Account] {
        oauthManager.accounts
            .sorted { account1, account2 in
                let balance1 = Double(account1.availableBalance.value) ?? 0
                let balance2 = Double(account2.availableBalance.value) ?? 0
                return balance1 > balance2
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Coinbase Authentication Section
            VStack(spacing: TerminalTheme.paddingSmall) {
                HStack {
                    Text("●")
                        .font(.system(size: 14))
                        .foregroundColor(TerminalTheme.cyan)
                    Text("COINBASE")
                        .font(TerminalTheme.monospaced(size: 14, weight: .bold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }
                .padding(.top, TerminalTheme.paddingSmall)

                if oauthManager.accessToken == nil {
                    VStack(spacing: TerminalTheme.paddingSmall) {
                        Button(action: {
                            oauthManager.oauthError = nil // Clear previous errors
                            oauthManager.startOAuthFlow(presentationAnchor: WindowPresentationAnchor())
                        }) {
                            HStack {
                                Text("🔑")
                                    .font(.system(size: 12))
                                Text("CONNECT COINBASE")
                                    .font(TerminalTheme.monospaced(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TerminalTheme.paddingMedium)
                            .background(TerminalTheme.cyan)
                            .foregroundColor(.black)
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.border, lineWidth: 1)
                            )
                        }

                        if let oauthError = oauthManager.oauthError {
                            HStack {
                                Text("⚠")
                                    .font(.system(size: 10))
                                    .foregroundColor(TerminalTheme.red)
                                Text(oauthError.uppercased())
                                    .font(TerminalTheme.monospaced(size: 9))
                                    .foregroundColor(TerminalTheme.textSecondary)
                            }
                            .padding(.vertical, TerminalTheme.paddingSmall)
                            .padding(.horizontal, TerminalTheme.paddingMedium)
                            .background(TerminalTheme.red.opacity(0.1))
                            .overlay(
                                Rectangle()
                                    .stroke(TerminalTheme.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    HStack(spacing: TerminalTheme.paddingSmall) {
                        Text("✓")
                            .font(.system(size: 12))
                            .foregroundColor(TerminalTheme.green)
                        Text("CONNECTED")
                            .font(TerminalTheme.monospaced(size: 10, weight: .medium))
                            .foregroundColor(TerminalTheme.green)
                    }
                    .padding(.vertical, TerminalTheme.paddingSmall)

                    Button(action: {
                        Task {
                            await oauthManager.logout()
                            showSuccessAlert = true
                        }
                    }) {
                        HStack {
                            Text("→")
                                .font(.system(size: 12))
                            Text("DISCONNECT")
                                .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TerminalTheme.paddingMedium)
                        .background(TerminalTheme.red.opacity(0.1))
                        .foregroundColor(TerminalTheme.red)
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.red, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(TerminalTheme.paddingMedium)
            .background(TerminalTheme.surface)
            .overlay(TerminalTheme.borderStyle())
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.top, TerminalTheme.paddingMedium)

            // Account Balances Section
            if oauthManager.accessToken != nil {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                    HStack {
                        HStack(spacing: TerminalTheme.paddingSmall) {
                            Text("💰")
                                .font(.system(size: 12))
                                .foregroundColor(TerminalTheme.cyan)
                            Text("TOP ACCOUNTS")
                                .font(TerminalTheme.monospaced(size: 12, weight: .bold))
                                .foregroundColor(TerminalTheme.textPrimary)
                        }
                        Spacer()
                        if oauthManager.isLoadingAccounts {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(TerminalTheme.cyan)
                        } else {
                            Button(action: {
                                Task {
                                    await oauthManager.fetchAccounts()
                                }
                            }) {
                                Text("↻")
                                    .font(TerminalTheme.monospaced(size: 12, weight: .bold))
                                    .foregroundColor(TerminalTheme.cyan)
                                    .frame(width: 20, height: 20)
                                    .background(TerminalTheme.cyan.opacity(0.1))
                                    .overlay(
                                        Rectangle()
                                            .stroke(TerminalTheme.cyan, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error = oauthManager.accountsError {
                        HStack {
                            Text("⚠")
                                .font(.system(size: 10))
                                .foregroundColor(TerminalTheme.amber)
                            Text(error.uppercased())
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(TerminalTheme.textSecondary)
                        }
                        .padding(.vertical, TerminalTheme.paddingSmall)
                        .padding(.horizontal, TerminalTheme.paddingMedium)
                        .background(TerminalTheme.amber.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.amber.opacity(0.3), lineWidth: 1)
                        )
                    }

                    if topAccounts.isEmpty && !oauthManager.isLoadingAccounts {
                        HStack {
                            Text("[]")
                                .font(.system(size: 12))
                                .foregroundColor(TerminalTheme.textSecondary)
                            Text("NO ACCOUNTS FOUND")
                                .font(TerminalTheme.monospaced(size: 10))
                                .foregroundColor(TerminalTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TerminalTheme.paddingMedium)
                    } else {
                        ScrollView {
                            VStack(spacing: TerminalTheme.paddingSmall) {
                                ForEach(Array(topAccounts.enumerated()), id: \.element.id) { index, account in
                                    AccountBalanceRow(account: account, rank: index + 1)
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                }
                .padding(TerminalTheme.paddingMedium)
                .background(TerminalTheme.surface)
                .overlay(TerminalTheme.borderStyle())
                .padding(.horizontal, TerminalTheme.paddingMedium)
                .padding(.top, TerminalTheme.paddingMedium)
            }
            
            // Simulation Data Section
            VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                HStack(spacing: TerminalTheme.paddingSmall) {
                    Text("📊")
                        .font(.system(size: 12))
                        .foregroundColor(TerminalTheme.amber)
                    Text("SIMULATION DATA")
                        .font(TerminalTheme.monospaced(size: 12, weight: .bold))
                        .foregroundColor(TerminalTheme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: TerminalTheme.paddingSmall) {
                    Button(action: {
                        showClearDataConfirmation = true
                    }) {
                        HStack {
                            Text("🗑")
                                .font(.system(size: 12))
                            Text("CLEAR ALL PERFORMANCE DATA")
                                .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TerminalTheme.paddingMedium)
                        .background(TerminalTheme.red.opacity(0.1))
                        .foregroundColor(TerminalTheme.red)
                        .overlay(
                            Rectangle()
                                .stroke(TerminalTheme.red, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(TerminalTheme.paddingMedium)
            .background(TerminalTheme.surface)
            .overlay(TerminalTheme.borderStyle())
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.top, TerminalTheme.paddingMedium)
            .padding(.bottom, TerminalTheme.paddingMedium)
        }
        .background(TerminalTheme.background)
        .alert("LOGGED OUT", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have been logged out of Coinbase.")
        }
        .alert("CLEAR ALL PERFORMANCE DATA", isPresented: $showClearDataConfirmation) {
            Button("CANCEL", role: .cancel) {}
            Button("CLEAR", role: .destructive) {
                clearPerformanceData()
            }
        } message: {
            Text("This will permanently delete all simulated orders and performance metrics. This action cannot be undone.")
        }
        .onAppear {
            oauthManager.loadTokens()
            if oauthManager.accessToken != nil {
                Task {
                    await oauthManager.fetchAccounts()
                }
            }
        }
        .onChange(of: oauthManager.accessToken) { _, newValue in
            if newValue != nil {
                Task {
                    await oauthManager.fetchAccounts()
                }
            } else {
                oauthManager.accounts = []
            }
        }
    }
    
    private func clearPerformanceData() {
        // Clear persisted data from UserDefaults
        SimulatedOrderManager.clearPersistedData()
        
        // Post a notification so any active SimulatedOrderManager instances can clear their in-memory data
        NotificationCenter.default.post(name: NSNotification.Name("ClearSimulationData"), object: nil)
    }
}

struct AccountBalanceRow: View {
    let account: Account
    let rank: Int

    var body: some View {
        HStack(spacing: TerminalTheme.paddingSmall) {
            // Rank badge
            ZStack {
                Rectangle()
                    .fill(TerminalTheme.cyan.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.cyan, lineWidth: 1)
                    )
                Text("\(rank)")
                    .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                    .foregroundColor(TerminalTheme.cyan)
            }

            // Account info
            VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                Text(account.name ?? account.currency)
                    .font(TerminalTheme.monospaced(size: 11, weight: .semibold))
                    .foregroundColor(TerminalTheme.textPrimary)
                HStack(spacing: TerminalTheme.paddingTiny) {
                    Text(account.currency)
                        .font(TerminalTheme.monospaced(size: 9, weight: .medium))
                        .foregroundColor(TerminalTheme.textSecondary)
                    if account.active == true {
                        Text("●")
                            .font(.system(size: 6))
                            .foregroundColor(TerminalTheme.green)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: TerminalTheme.paddingTiny) {
                Text(formatBalance(account.availableBalance.value))
                    .font(TerminalTheme.monospaced(size: 11, weight: .bold))
                    .foregroundColor(TerminalTheme.textPrimary)
                Text(account.availableBalance.currency)
                    .font(TerminalTheme.monospaced(size: 9))
                    .foregroundColor(TerminalTheme.textSecondary)
            }
        }
        .padding(TerminalTheme.paddingSmall)
        .background(TerminalTheme.background)
        .overlay(
            Rectangle()
                .stroke(TerminalTheme.border.opacity(0.5), lineWidth: 1)
        )
    }

    private func formatBalance(_ amount: String) -> String {
        guard let value = Double(amount) else {
            return amount
        }

        if value == 0 {
            return "0.00"
        } else if value < 0.01 {
            return String(format: "%.8f", value).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        } else if value < 1 {
            return String(format: "%.4f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
