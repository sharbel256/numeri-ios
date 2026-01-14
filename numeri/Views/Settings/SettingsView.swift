//
//  SettingsView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Binding var appColorScheme: AppColorScheme
    @StateObject private var oauthManager = OAuthManager()
    @State private var showSuccessAlert: Bool = false
    
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
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Coinbase")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 8)
                    
                    if oauthManager.accessToken == nil {
                        VStack(spacing: 12) {
                            Button(action: {
                                oauthManager.oauthError = nil // Clear previous errors
                                oauthManager.startOAuthFlow(presentationAnchor: WindowPresentationAnchor())
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.key.fill")
                                    Text("Connect Coinbase")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .font(.headline)
                                .cornerRadius(12)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            if let oauthError = oauthManager.oauthError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(oauthError)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            Task {
                                await oauthManager.logout()
                                showSuccessAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Disconnect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.background)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Account Balances Section
                if oauthManager.accessToken != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "wallet.pass.fill")
                                    .foregroundColor(.blue)
                                Text("Top Accounts")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            if oauthManager.isLoadingAccounts {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button(action: {
                                    Task {
                                        await oauthManager.fetchAccounts()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        if let error = oauthManager.accountsError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if topAccounts.isEmpty && !oauthManager.isLoadingAccounts {
                            HStack {
                                Image(systemName: "tray")
                                    .foregroundColor(.secondary)
                                Text("No accounts found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(Array(topAccounts.enumerated()), id: \.element.id) { index, account in
                                        AccountBalanceRow(account: account, rank: index + 1)
                                    }
                                }
                            }
                            .frame(maxHeight: 400)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.background)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Appearance Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.purple)
                        Text("Appearance")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Picker("Color Scheme", selection: $appColorScheme) {
                        Text("System").tag(AppColorScheme.system)
                        Text("Light").tag(AppColorScheme.light)
                        Text("Dark").tag(AppColorScheme.dark)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.background)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
        }
        .alert("Logged Out", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You have been logged out of Coinbase.")
            }
        .onAppear {
            oauthManager.loadTokens()
            if oauthManager.accessToken != nil {
                Task {
                    await oauthManager.fetchAccounts()
                }
            }
        }
        .onChange(of: oauthManager.accessToken) { oldValue, newValue in
            if newValue != nil {
                Task {
                    await oauthManager.fetchAccounts()
                }
            } else {
                oauthManager.accounts = []
            }
        }
    }
}

struct AccountBalanceRow: View {
    let account: Account
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            // Account info
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name ?? account.currency)
                    .font(.headline)
                    .fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text(account.currency)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    if account.active == true {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            
            Spacer()
            
            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBalance(account.availableBalance.value))
                    .font(.headline)
                    .fontWeight(.bold)
                Text(account.availableBalance.currency)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
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

